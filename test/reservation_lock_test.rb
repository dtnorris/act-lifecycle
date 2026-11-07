# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "json"
require "rbconfig"
require "timeout"
require "tmpdir"
require_relative "../lib/act_lifecycle"

# Uses real files, identities and separate interpreters; no lock or Git fakes.
class ReservationLockTest < Minitest::Test
  BUSY = "reservation lock: launch/recovery reservation busy; retry"
  FOREIGN = "reservation: foreign/symlinked lock"

  # Creates a private disposable canonical data root. Returns setup's result;
  # filesystem errors propagate before any lock is used.
  def setup
    @directory = File.realpath(Dir.mktmpdir("reservation-contract-"))
    @data = File.join(@directory, "data")
    Dir.mkdir(@data, 0o700)
    @runs = "#{@data}-runs"
    @path = File.join(@runs, "launch.lock")
  end

  # Removes only this case's disposable files after handles/children close.
  # Returns FileUtils' result; cleanup errors remain test errors.
  def teardown
    FileUtils.remove_entry(@directory)
  end

  # Checks exact refusal and that no protected effect occurred. Returns the
  # exception; assertion failures expose changed messages or unsafe admission.
  def refusal(message, root: @data, held: nil)
    affected = false
    error = assert_raises(ActLifecycle::InvalidState) do
      ActLifecycle::ReservationLock.synchronize(root, held: held) { affected = true }
    end
    assert_equal message, error.message
    refute affected
    error
  end

  # Launches one real, independent interpreter and bounds its entire lifetime.
  # Returns parsed output and genuine status; timeout kills/reaps before raising.
  def contend
    effect = File.join(@directory, "effect")
    reader, writer = IO.pipe
    process = Process.spawn(RbConfig.ruby, File.join(__dir__, "support/reservation_contender.rb"),
      @data, effect, out: writer)
    writer.close
    Timeout.timeout(2) do
      assert IO.select([reader], nil, nil, 1), "contender did not report within deadline"
      record = JSON.parse(reader.read)
      _, status = Process.wait2(process)
      process = nil
      [record, status, File.exist?(effect)]
    end
  ensure
    reader&.close
    writer&.close unless writer&.closed?
    if process
      Process.kill("KILL", process)
      Process.wait(process)
    end
  end

  # Proves canonical namespace, real uid/mode/link/inode and block return values.
  # A data-root alias must use exactly the same lock, without a second namespace.
  def test_canonical_private_identity_and_returns
    alias_path = File.join(@directory, "alias")
    File.symlink(@data, alias_path)
    owned = nil
    token = Object.new
    assert_same token, ActLifecycle::ReservationLock.synchronize(alias_path) { |lock|
      owned = lock
      actual = File.lstat(@path)
      assert_equal [actual.dev, actual.ino], [lock.stat.dev, lock.stat.ino]
      assert_equal Process.uid, actual.uid
      assert_equal Process.uid, File.stat(@runs).uid
      assert_equal 0o700, File.stat(@runs).mode & 0o777
      assert_equal 0o600, actual.mode & 0o777
      assert_equal 1, actual.nlink
      refute File.exist?("#{alias_path}-runs")
      token
    }
    assert owned.closed?
    [false, 23].each do |value|
      assert_equal value, ActLifecycle::ReservationLock.synchronize(@data) { value }
    end
    assert_nil ActLifecycle::ReservationLock.synchronize(@data) { nil }
    refute ActLifecycle::ReservationLock.respond_to?(:validate!)
  end

  # A separate process refuses before its mutator, including during borrowed
  # use and after borrowed return. Release then admits a fresh process/handle.
  def test_process_contention_borrowed_lifetime_and_release
    ActLifecycle::ReservationLock.synchronize(@data) do |lock|
      assert_equal :borrowed, ActLifecycle::ReservationLock.synchronize(@data, held: lock) { |borrowed|
        assert_same lock, borrowed
        :borrowed
      }
      refute lock.closed?
      assert_equal true, ActLifecycle::ReservationLock.send(:validate!, @path, lock)
      record, status, affected = contend
      refute affected
      assert_equal 75, status.exitstatus
      assert_equal BUSY, record.fetch("error")
      File.open(@path, File::RDWR) { |other| refusal(BUSY, held: other) }
      assert_equal false, ActLifecycle::ReservationLock.synchronize(@data, held: lock) { false }
      refute lock.closed?
    end
    record, status, affected = contend
    assert status.success?
    assert_equal "acquired", record.fetch("result")
    assert affected
    assert_equal :fresh, ActLifecycle::ReservationLock.synchronize(@data) { :fresh }
  end

  # Owned handles close on exceptions; borrowed handles retain ownership and
  # exclusivity even when the nested block raises the caller's exact exception.
  def test_exception_identity_and_owned_versus_borrowed_cleanup
    failure = RuntimeError.new("caller failed")
    owned = nil
    assert_same failure, assert_raises(RuntimeError) {
      ActLifecycle::ReservationLock.synchronize(@data) { |lock| owned = lock; raise failure }
    }
    assert owned.closed?
    ActLifecycle::ReservationLock.synchronize(@data) do |lock|
      assert_same failure, assert_raises(RuntimeError) {
        ActLifecycle::ReservationLock.synchronize(@data, held: lock) { raise failure }
      }
      refute lock.closed?
      record, status, affected = contend
      refute affected
      assert_equal 75, status.exitstatus
      assert_equal BUSY, record.fetch("error")
    end
    assert_nil ActLifecycle::ReservationLock.synchronize(@data) { nil }
  end

  # Files, symlinks (including dangling targets), and public evidence roots
  # refuse before block execution; private owned directories remain usable.
  def test_unsafe_evidence_roots
    File.write(@runs, "foreign")
    refusal("reservation: foreign evidence root")
    File.unlink(@runs)
    [@data, File.join(@directory, "missing")].each do |target|
      File.symlink(target, @runs)
      refusal("reservation: symlinked evidence path")
      File.unlink(@runs)
    end
    Dir.mkdir(@runs, 0o700)
    File.chmod(0o750, @runs)
    refusal("reservation: foreign evidence root")
    File.chmod(0o700, @runs)
    assert_equal :private, ActLifecycle::ReservationLock.synchronize(@data) { :private }
  end

  # Real lock directories, dangling/live symlinks, public modes and hard links
  # refuse. Existing target bytes survive each attempted acquisition unchanged.
  def test_foreign_symlinked_public_and_multiple_link_locks
    Dir.mkdir(@runs, 0o700)
    Dir.mkdir(@path, 0o700)
    refusal(FOREIGN)
    Dir.rmdir(@path)
    target = File.join(@directory, "target")
    File.write(target, "unchanged", perm: 0o600)
    [target, File.join(@directory, "missing")].each do |destination|
      File.symlink(destination, @path)
      refusal(FOREIGN)
      File.unlink(@path)
    end
    assert_equal "unchanged", File.read(target)
    File.write(@path, "lock bytes", perm: 0o600)
    File.chmod(0o640, @path)
    refusal(FOREIGN)
    File.chmod(0o600, @path)
    File.link(@path, File.join(@directory, "extra-link"))
    refusal(FOREIGN)
    assert_equal "lock bytes", File.read(@path)
  end

  # Tokens opened on other roots or on replaced/unlinked inodes never authorize
  # effects. Closed or malformed tokens preserve Ruby's original IO exceptions.
  def test_foreign_replaced_closed_and_malformed_borrowed_tokens
    other_data = File.join(@directory, "other")
    Dir.mkdir(other_data, 0o700)
    ActLifecycle::ReservationLock.synchronize(@data) do |lock|
      ActLifecycle::ReservationLock.synchronize(other_data) { |other| refusal(FOREIGN, held: other) }
      File.rename(@path, File.join(@directory, "old-lock"))
      File.write(@path, "replacement", perm: 0o600)
      refusal(FOREIGN, held: lock)
      File.unlink(@path)
      File.symlink(File.join(@directory, "old-lock"), @path)
      refusal(FOREIGN, held: lock)
      File.unlink(@path)
      assert_raises(Errno::ENOENT) { ActLifecycle::ReservationLock.synchronize(@data, held: lock) { flunk } }
    end
    ActLifecycle::ReservationLock.synchronize(@data) { nil }
    closed = File.open(@path, File::RDWR)
    closed.close
    assert_raises(IOError) { ActLifecycle::ReservationLock.synchronize(@data, held: closed) { flunk } }
    assert_raises(NoMethodError) { ActLifecycle::ReservationLock.synchronize(@data, held: Object.new) { flunk } }
    assert_raises(Errno::ENOENT) { ActLifecycle::ReservationLock.synchronize(File.join(@directory, "absent")) { flunk } }
  end
end
