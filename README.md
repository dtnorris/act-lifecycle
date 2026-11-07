# act-lifecycle

An independently installable Ruby package with the `ActLifecycle` namespace.
It supplies the existing reservation lock contract; main adoption and composed
M3/M4 acceptance belong to AB-LC-01C under the authoritative
[breakup plan](https://github.com/dtnorris/agent-coding-tool-data/blob/4d297dcc6bd8574c2c103125abf453d8673aafec/plans/ab/AB-PLN-01A/plan.md).

```ruby
require "act_lifecycle"
ActLifecycle::VERSION # => "0.1.0"
ActLifecycle::ReservationLock.synchronize(data_root) do |lock|
  # Perform the caller's protected operation; its return value is preserved.
end
```

The gem has no runtime gem dependencies, imports no other ACT repository, and
does not read `.env`. Main ACT retains command and mode-selection authority.
Publication, exact dependency refs, installed-ACT adoption and successor
preparation require operator review. No split-mode composition is declared here.

The reservation is exactly `File.realpath(data_root) + "-runs/launch.lock"`.
The package checks private ownership, mode, link count and open/path inode
identity, then takes a nonblocking exclusive flock. Unsafe or busy reservations
raise `ActLifecycle::InvalidState` with the existing messages; filesystem/IO
errors propagate. Passing `held: lock` revalidates the same IO and leaves it open
and held for its caller, including when the protected operation raises. Owned
handles close on return or exception. Callers retain command/state authority;
this package creates no state writer or second reservation. AB-LC-01C owns error
translation at the main facade and proof of legacy/split process contention.

Install development dependencies with `bundle install` (separate from test
timing). Both `rake` and `bundle exec rake` run the **same entire default suite**,
with recursive `test/**/*_test.rb` discovery, genuine Minitest accounting, no
skips or selection flags, and fresh line/branch coverage of every production
file. Test-only helpers live under `test/support`; future `bin/` and `exe/`
production files join the coverage inventory. Unloaded files, unmeasured nodes,
missing/stale/corrupt results and unfinished descendants fail the gate. Coverage
hits never carry across runs. Each test file must define at least one case.

`test/coverage_floors.json` records the measured bootstrap executable nodes and
100% line/branch floors; files without branches report an empty branch inventory.
The lock and local error also have measured 100% floors, including all 16 lock
branch arms. `test/reservation_lock_reference.json` binds the original source
and accepted covered-node evidence: 31/33 lines (93.93939393939394%) and 13/16
branch arms (81.25%). The source denominator was compiled under the original
execution guard; no native-Git baseline was run. Namespace-only extraction keeps
node coordinates unchanged, and the default verifier enforces every mapped hit
as well as numeric floors. Host qualification must confirm these fresh maps on
its actual Ruby/platform; focused worker coverage does not accept adoption.

The initial timing contract targets David's Darwin arm64 Mac with Ruby 4.0.6
and this lockfile. The private watchdog supervises test startup through cleanup,
coverage verification and reporting. Native `proc_pid_rusage` and
`mach_absolute_time` debit Ruby/Bundler/Rake process startup from ten seconds;
0.25 seconds is reserved for process shutdown and launcher overhead. The
independent watchdog kills the parent and the test process group on exhaustion.
Unsupported clock APIs fail closed; package imports remain independent of the
test host. No environment variable changes the cap or disables coverage.

Kernel process age cannot observe time spent in a preceding shell/tool shim.
The operator must qualify the **outer launch-to-exit** time for both ordinary
commands on the named host, including those launchers, within ten seconds and
confirm the 0.25-second reserve covers their gap. A private runner measurement
alone is insufficient. Host checkpoint-gated measurements remain distinct from
focused worker checks; a new launcher/runtime/host requires requalification.
The successful final JSON reports remaining budget after temporary-file cleanup.
For an ordinary invocation, `10 - 0.25 - budget_remaining_seconds` is native
process age at that observation; compare outer elapsed time against it to
qualify the launcher/shutdown gap. Fixture deadlines are private fault controls
and do not supply host timing evidence.

Contributions follow the canonical
[coding](https://github.com/dtnorris/agent-skills/blob/8ac096dd81865ea9e30ef84c6a8127db68e159bb/skills/karpathy-manning-dtnorris-guidelines/SKILL.md)
and [planning](https://github.com/dtnorris/agent-skills/blob/8ac096dd81865ea9e30ef84c6a8127db68e159bb/skills/agentic-task-planning/SKILL.md)
guidance, subject to task-specific authority. This README describes the package
and its bootstrap developer contract; the cross-repository plan remains the
architectural authority.
