# frozen_string_literal: true

require "minitest/autorun"
require "digest"
require "json"
require_relative "../lib/act_lifecycle"

# Proves package identity, independence and source-bound lock extraction.
class PackageTest < Minitest::Test
  # Loads the package from its own checkout and verifies its initial version.
  # Accepts no arguments; assertion failures describe a broken scaffold identity.
  def test_independent_package_identity
    assert_equal "0.1.0", ActLifecycle::VERSION
    assert_equal "ActLifecycle", ActLifecycle.name
  end

  # Checks the distributable gem's identity, source inventory and dependency
  # independence. Missing/invalid metadata raises RubyGems validation errors.
  def test_installable_gem_specification
    specification = Gem::Specification.load(File.expand_path("../act-lifecycle.gemspec", __dir__))
    assert_equal "act-lifecycle", specification.name
    assert_equal ActLifecycle::VERSION, specification.version.to_s
    assert_empty specification.runtime_dependencies
    assert_equal Dir["lib/**/*.rb"].sort, specification.files.grep(/\Alib\//).sort
    assert specification.validate
  end

  # Binds the namespace-only extraction and inherited numeric/covered-node floors
  # to the accepted source evidence. Returns assertions; drift fails explicitly.
  def test_original_lock_source_and_coverage_mapping
    reference = JSON.parse(File.read(File.join(__dir__, "reservation_lock_reference.json")))
    source = File.read(File.expand_path("../lib/act_lifecycle/reservation_lock.rb", __dir__))
    assert_equal reference.fetch("source_sha256"), Digest::SHA256.hexdigest(source.sub("module ActLifecycle", "module AgentCodingTool"))
    floor = JSON.parse(File.read(File.join(__dir__, "coverage_floors.json"))).fetch("lib/act_lifecycle/reservation_lock.rb")
    assert_operator floor.fetch("line_percent"), :>=, reference.fetch("line_percent")
    assert_operator floor.fetch("branch_percent"), :>=, reference.fetch("branch_percent")
    assert_empty reference.fetch("covered_lines") - floor.fetch("covered_lines")
    reference.fetch("covered_branches").each do |origin, arms|
      assert_empty arms - floor.fetch("covered_branches").fetch(origin)
    end
  end
end
