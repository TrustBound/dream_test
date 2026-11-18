//// Black-box tests of where suite-level and group-level hooks run.
////
//// A hook that starts a resource the way a user does, for example a pool
//// that links to the caller or an ETS table that the caller owns, must find
//// that resource alive in the tests that it serves. Each scope has one
//// owner process for its hooks, and each test has one process for its
//// hooks and its body. The runner waits for each hook with a timeout, so a
//// hook that never returns or kills its process does not stop the run.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/sandbox.{type SandboxResult, SandboxCompleted, SandboxConfig}
import dream_test/types.{
  type AssertionResult, type Status, type TestResult, AfterAllHook,
  AfterAllSuitesHook, AfterEachHook, AfterEachSuiteHook, AssertionFailure,
  AssertionOk, BeforeAllHook, BeforeAllSuitesHook, BeforeEachSuiteHook, Failed,
  Passed, ScopeLost, SetupFailed, TeardownFailure, TimedOut,
}
import dream_test/unit.{describe, it}
import dream_test/unit_context
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Name, type Pid}
import gleam/list
import gleam/otp/actor
import gleam/otp/static_supervisor
import gleam/result

pub fn tests() {
  describe("hook resources", [
    it("a pool that before_all starts lives for the tests of its group", fn() {
      unit_context.describe("pool group", NoPool, [
        unit_context.before_all(start_pool_in_context),
        unit_context.it("uses the pool", pool_in_context_is_alive),
        unit_context.after_all(stop_pool_in_context),
      ])
      |> run_suite
      |> statuses
      |> should
      |> be_equal([#("uses the pool", Passed)])
      |> or_fail_with("the pool from before_all should live for the test")
    }),

    it(
      "an ETS table that before_all makes lives for the tests of its group",
      fn() {
        unit_context.describe(
          "table group",
          atom.create("dream_test_before_all_table"),
          [
            unit_context.before_all(make_table),
            unit_context.it("uses the table", table_in_context_exists),
            unit_context.after_all(remove_table),
          ],
        )
        |> run_suite
        |> statuses
        |> should
        |> be_equal([#("uses the table", Passed)])
        |> or_fail_with(
          "the ETS table from before_all should live for the test",
        )
      },
    ),

    it("a pool that before_all_suites starts lives for the tests", fn() {
      let pool_name = process.new_name("dream_test_suite_pool")
      runner.new([
        unit_context.describe("pool suite", pool_name, [
          unit_context.it("uses the pool", named_pool_is_alive),
        ]),
      ])
      |> runner.before_all_suites(fn(_suites) { start_named_pool(pool_name) })
      |> runner.after_all_suites(fn(_suites) { stop_named_pool(pool_name) })
      |> runner.run()
      |> types.report_tests
      |> statuses
      |> should
      |> be_equal([#("uses the pool", Passed)])
      |> or_fail_with(
        "the pool from before_all_suites should live for the test",
      )
    }),

    it("a before_all_suites hook that crashes gives SetupFailed", fn() {
      runner.new([describe("suite", [it("a", passing_test)])])
      |> runner.before_all_suites(fn(_suites) { erlang_error(boom()) })
      |> runner.run()
      |> types.report_tests
      |> failures
      |> should
      |> be_equal([
        #("a", SetupFailed, [
          #("before_all_suites", "hook crashed: error:boom"),
        ]),
      ])
      |> or_fail_with("a crash in before_all_suites should fail the tests")
    }),

    it("a before_each_suite hook that crashes gives SetupFailed", fn() {
      runner.new([describe("suite", [it("a", passing_test)])])
      |> runner.before_each_suite(fn(_suite) { erlang_error(boom()) })
      |> runner.run()
      |> types.report_tests
      |> failures
      |> should
      |> be_equal([
        #("a", SetupFailed, [
          #("before_each_suite", "hook crashed in suite: error:boom"),
        ]),
      ])
      |> or_fail_with("a crash in before_each_suite should fail the tests")
    }),

    it("an after_each_suite hook that crashes is a tear-down failure", fn() {
      runner.new([describe("suite", [it("a", passing_test)])])
      |> runner.after_each_suite(fn(_suite) { erlang_error(boom()) })
      |> runner.run()
      |> types.report_teardown_failures
      |> should
      |> be_equal([
        TeardownFailure(
          hook: AfterEachSuiteHook,
          scope: ["suite"],
          message: "hook crashed in suite: error:boom",
        ),
      ])
      |> or_fail_with(
        "a crash in after_each_suite should be a tear-down failure",
      )
    }),

    it("a pool that before_each starts lives for the test body", fn() {
      unit_context.describe("pool test", NoPool, [
        unit_context.before_each(start_pool_in_context),
        unit_context.it("uses the pool", pool_in_context_is_alive),
        unit_context.after_each(stop_pool_in_context),
      ])
      |> run_suite
      |> statuses
      |> should
      |> be_equal([#("uses the pool", Passed)])
      |> or_fail_with("the pool from before_each should live for the body")
    }),

    it("an ETS table that before_each makes lives for the test body", fn() {
      unit_context.describe(
        "table test",
        atom.create("dream_test_before_each_table"),
        [
          unit_context.before_each(make_table),
          unit_context.it("uses the table", table_in_context_exists),
          unit_context.after_each(remove_table),
        ],
      )
      |> run_suite
      |> statuses
      |> should
      |> be_equal([#("uses the table", Passed)])
      |> or_fail_with("the ETS table from before_each should live for the body")
    }),

    it("a before_all that never returns gives SetupFailed", fn() {
      describe("root", [
        unit.before_all(hang),
        it("a", passing_test),
      ])
      |> run_bounded
      |> should
      |> be_equal(
        SandboxCompleted(
          RunSummary(
            tests: [
              #("a", SetupFailed, [#("before_all", "hook timed out in root")]),
            ],
            teardown_failures: [],
          ),
        ),
      )
      |> or_fail_with("a hanging before_all should time out")
    }),

    it("an after_all that never returns is a tear-down failure", fn() {
      describe("root", [
        it("a", passing_test),
        unit.after_all(hang),
      ])
      |> run_bounded
      |> should
      |> be_equal(
        SandboxCompleted(
          RunSummary(tests: [#("a", Passed, [])], teardown_failures: [
            TeardownFailure(
              hook: AfterAllHook,
              scope: ["root"],
              message: "hook timed out in root",
            ),
          ]),
        ),
      )
      |> or_fail_with("a hanging after_all should be a tear-down failure")
    }),

    it("a before_all_suites hook that never returns gives SetupFailed", fn() {
      runner.new([describe("suite", [it("a", passing_test)])])
      |> runner.before_all_suites(fn(_suites) { hang() })
      |> run_builder_bounded
      |> should
      |> be_equal(
        SandboxCompleted(
          RunSummary(
            tests: [
              #("a", SetupFailed, [#("before_all_suites", "hook timed out")]),
            ],
            teardown_failures: [],
          ),
        ),
      )
      |> or_fail_with("a hanging before_all_suites should time out")
    }),

    it(
      "an after_all_suites hook that never returns is a tear-down failure",
      fn() {
        runner.new([describe("suite", [it("a", passing_test)])])
        |> runner.after_all_suites(fn(_suites) { hang() })
        |> run_builder_bounded
        |> should
        |> be_equal(
          SandboxCompleted(
            RunSummary(tests: [#("a", Passed, [])], teardown_failures: [
              TeardownFailure(
                hook: AfterAllSuitesHook,
                scope: [],
                message: "hook timed out",
              ),
            ]),
          ),
        )
        |> or_fail_with(
          "a hanging after_all_suites should be a tear-down failure",
        )
      },
    ),

    it("a before_each_suite hook that never returns gives SetupFailed", fn() {
      runner.new([describe("suite", [it("a", passing_test)])])
      |> runner.before_each_suite(fn(_suite) { hang() })
      |> run_builder_bounded
      |> should
      |> be_equal(
        SandboxCompleted(
          RunSummary(
            tests: [
              #("a", SetupFailed, [
                #("before_each_suite", "hook timed out in suite"),
              ]),
            ],
            teardown_failures: [],
          ),
        ),
      )
      |> or_fail_with("a hanging before_each_suite should time out")
    }),

    it(
      "an after_each_suite hook that never returns is a tear-down failure",
      fn() {
        runner.new([describe("suite", [it("a", passing_test)])])
        |> runner.after_each_suite(fn(_suite) { hang() })
        |> run_builder_bounded
        |> should
        |> be_equal(
          SandboxCompleted(
            RunSummary(tests: [#("a", Passed, [])], teardown_failures: [
              TeardownFailure(
                hook: AfterEachSuiteHook,
                scope: ["suite"],
                message: "hook timed out in suite",
              ),
            ]),
          ),
        )
        |> or_fail_with(
          "a hanging after_each_suite should be a tear-down failure",
        )
      },
    ),

    it("a body that times out still runs after_each with its context", fn() {
      let reports = process.new_subject()
      unit_context.describe("root", "start", [
        unit_context.before_each(fn(_context) { Ok("set up") }),
        unit_context.it("hangs", fn(_context) { hang() }),
        unit_context.after_each(fn(context) {
          process.send(reports, context)
          Ok(Nil)
        }),
      ])
      |> run_bounded
      |> result_and_report(reports)
      |> should
      |> be_equal(#(
        SandboxCompleted(
          RunSummary(
            tests: [#("hangs", TimedOut, [#("timeout", "test timed out")])],
            teardown_failures: [],
          ),
        ),
        Ok("set up"),
      ))
      |> or_fail_with("after_each should run after a body that timed out")
    }),

    it("a test process that is killed still runs after_each", fn() {
      let reports = process.new_subject()
      unit_context.describe("root", "start", [
        unit_context.before_each(fn(_context) { Ok("set up") }),
        unit_context.it("kills itself", fn(_context) { kill_self() }),
        unit_context.after_each(fn(context) {
          process.send(reports, context)
          Ok(Nil)
        }),
      ])
      |> run_bounded
      |> result_and_report(reports)
      |> should
      |> be_equal(#(
        SandboxCompleted(
          RunSummary(
            tests: [
              #("kills itself", Failed, [
                #("crash", "worker crashed in root: killed"),
              ]),
            ],
            teardown_failures: [],
          ),
        ),
        Ok("set up"),
      ))
      |> or_fail_with("after_each should run after the test process died")
    }),

    it("a before_all that kills its process fails its group only", fn() {
      runner.new([
        describe("first", [
          unit.before_all(fn() { kill_self() }),
          it("a", passing_test),
        ]),
        describe("second", [it("b", passing_test)]),
      ])
      |> run_builder_bounded
      |> should
      |> be_equal(
        SandboxCompleted(
          RunSummary(
            tests: [
              #("a", SetupFailed, [
                #("before_all", "hook crashed in first: killed"),
              ]),
              #("b", Passed, []),
            ],
            teardown_failures: [],
          ),
        ),
      )
      |> or_fail_with("a killed before_all process should fail its group")
    }),

    it("a before_all process that dies during the tests is reported", fn() {
      let reports = process.new_subject()
      describe("root", [
        unit.before_all(fn() {
          start_linked_crash()
          Ok(Nil)
        }),
        it("a", fn() {
          process.sleep(30)
          Ok(AssertionOk)
        }),
        unit.after_all(fn() {
          process.send(reports, "after_all ran")
          Ok(Nil)
        }),
      ])
      |> run_bounded
      |> result_and_report(reports)
      |> should
      |> be_equal(#(
        SandboxCompleted(
          RunSummary(tests: [#("a", Passed, [])], teardown_failures: [
            ScopeLost(set_up: BeforeAllHook, scope: ["root"], reason: "Boom"),
          ]),
        ),
        Ok("after_all ran"),
      ))
      |> or_fail_with("the death of the before_all process should be reported")
    }),

    it("a lost group scope without after_all is reported", fn() {
      describe("root", [
        unit.before_all(fn() {
          start_linked_crash()
          Ok(Nil)
        }),
        it("a", fn() {
          process.sleep(30)
          Ok(AssertionOk)
        }),
      ])
      |> run_bounded
      |> should
      |> be_equal(
        SandboxCompleted(
          RunSummary(tests: [#("a", Passed, [])], teardown_failures: [
            ScopeLost(set_up: BeforeAllHook, scope: ["root"], reason: "Boom"),
          ]),
        ),
      )
      |> or_fail_with("a lost scope should be reported without after_all")
    }),

    it("the tests that have not started in a lost group do not run", fn() {
      let reports = process.new_subject()
      runner.new([
        describe("root", [
          unit.before_all(fn() {
            start_linked_crash()
            Ok(Nil)
          }),
          it("a", fn() {
            process.sleep(30)
            Ok(AssertionOk)
          }),
          it("b", fn() {
            process.send(reports, "b ran")
            Ok(AssertionOk)
          }),
          unit.after_all(fn() {
            process.send(reports, "after_all ran")
            Ok(Nil)
          }),
        ]),
      ])
      |> runner.max_concurrency(1)
      |> run_builder_bounded
      |> result_and_report(reports)
      |> should
      |> be_equal(#(
        SandboxCompleted(
          RunSummary(
            tests: [
              #("a", Passed, []),
              #("b", SetupFailed, [
                #("before_all", "before_all process exited in root: Boom"),
              ]),
            ],
            teardown_failures: [
              ScopeLost(set_up: BeforeAllHook, scope: ["root"], reason: "Boom"),
            ],
          ),
        ),
        Ok("after_all ran"),
      ))
      |> or_fail_with("b should not run after the scope is lost")
    }),

    it("every group after a lost scope gives SetupFailed", fn() {
      runner.new([
        describe("root", [
          unit.before_all(fn() {
            start_linked_crash()
            Ok(Nil)
          }),
          it("a", fn() {
            process.sleep(30)
            Ok(AssertionOk)
          }),
          unit.group("first", [it("c", passing_test)]),
          unit.group("second", [it("d", passing_test)]),
        ]),
      ])
      |> run_builder_bounded
      |> should
      |> be_equal(
        SandboxCompleted(
          RunSummary(
            tests: [
              #("a", Passed, []),
              #("c", SetupFailed, [
                #("before_all", "before_all process exited in root: Boom"),
              ]),
              #("d", SetupFailed, [
                #("before_all", "before_all process exited in root: Boom"),
              ]),
            ],
            teardown_failures: [
              ScopeLost(set_up: BeforeAllHook, scope: ["root"], reason: "Boom"),
            ],
          ),
        ),
      )
      |> or_fail_with("no group should start after the scope is lost")
    }),

    it("a group in a lost scope does not run its before_all", fn() {
      let reports = process.new_subject()
      runner.new([
        describe("root", [
          unit.before_all(fn() {
            start_linked_crash()
            Ok(Nil)
          }),
          it("a", fn() {
            process.sleep(30)
            Ok(AssertionOk)
          }),
          unit.group("inner", [
            unit.before_all(fn() {
              process.send(reports, "inner before_all ran")
              Ok(Nil)
            }),
            it("c", passing_test),
          ]),
        ]),
      ])
      |> runner.max_concurrency(1)
      |> run_builder_bounded
      |> result_and_report(reports)
      |> should
      |> be_equal(#(
        SandboxCompleted(
          RunSummary(
            tests: [
              #("a", Passed, []),
              #("c", SetupFailed, [
                #("before_all", "before_all process exited in root: Boom"),
              ]),
            ],
            teardown_failures: [
              ScopeLost(set_up: BeforeAllHook, scope: ["root"], reason: "Boom"),
            ],
          ),
        ),
        Error(Nil),
      ))
      |> or_fail_with("the inner group should not start in a lost scope")
    }),

    it("a before_each that never returns gives SetupFailed", fn() {
      describe("root", [
        unit.before_each(hang),
        it("a", passing_test),
      ])
      |> run_bounded
      |> should
      |> be_equal(
        SandboxCompleted(
          RunSummary(
            tests: [
              #("a", SetupFailed, [#("before_each", "hook timed out in root")]),
            ],
            teardown_failures: [],
          ),
        ),
      )
      |> or_fail_with("a hanging before_each should time out")
    }),

    it("an after_each that kills its process is a tear-down failure", fn() {
      describe("root", [
        it("a", passing_test),
        unit.after_each(fn() { kill_self() }),
      ])
      |> run_bounded
      |> should
      |> be_equal(
        SandboxCompleted(
          RunSummary(tests: [#("a", Passed, [])], teardown_failures: [
            TeardownFailure(
              hook: AfterEachHook,
              scope: ["root", "a"],
              message: "hook crashed in root: killed",
            ),
          ]),
        ),
      )
      |> or_fail_with("a killed after_each process should be reported")
    }),

    it("an after_all that crashes is a tear-down failure", fn() {
      describe("root", [
        it("a", passing_test),
        unit.after_all(fn() { erlang_error(boom()) }),
      ])
      |> run_bounded
      |> should
      |> be_equal(
        SandboxCompleted(
          RunSummary(tests: [#("a", Passed, [])], teardown_failures: [
            TeardownFailure(
              hook: AfterAllHook,
              scope: ["root"],
              message: "hook crashed in root: error:boom",
            ),
          ]),
        ),
      )
      |> or_fail_with("a crashing after_all should be a tear-down failure")
    }),

    it("an after_all that kills its process is a tear-down failure", fn() {
      describe("root", [
        it("a", passing_test),
        unit.after_all(fn() { kill_self() }),
      ])
      |> run_bounded
      |> should
      |> be_equal(
        SandboxCompleted(
          RunSummary(tests: [#("a", Passed, [])], teardown_failures: [
            TeardownFailure(
              hook: AfterAllHook,
              scope: ["root"],
              message: "hook crashed in root: killed",
            ),
          ]),
        ),
      )
      |> or_fail_with("a killed after_all process should be reported")
    }),

    it(
      "a before_all_suites hook that kills its process gives SetupFailed",
      fn() {
        runner.new([describe("suite", [it("a", passing_test)])])
        |> runner.before_all_suites(fn(_suites) { kill_self() })
        |> run_builder_bounded
        |> should
        |> be_equal(
          SandboxCompleted(
            RunSummary(
              tests: [
                #("a", SetupFailed, [
                  #("before_all_suites", "hook crashed: killed"),
                ]),
              ],
              teardown_failures: [],
            ),
          ),
        )
        |> or_fail_with("a killed before_all_suites process should be reported")
      },
    ),

    it(
      "an after_each_suite hook that kills its process is a tear-down failure",
      fn() {
        runner.new([describe("suite", [it("a", passing_test)])])
        |> runner.after_each_suite(fn(_suite) { kill_self() })
        |> run_builder_bounded
        |> should
        |> be_equal(
          SandboxCompleted(
            RunSummary(tests: [#("a", Passed, [])], teardown_failures: [
              TeardownFailure(
                hook: AfterEachSuiteHook,
                scope: ["suite"],
                message: "hook crashed in suite: killed",
              ),
            ]),
          ),
        )
        |> or_fail_with("a killed after_each_suite process should be reported")
      },
    ),

    it("a before_all_suites process that dies during the run is reported", fn() {
      runner.new([
        describe("suite", [
          it("a", fn() {
            process.sleep(30)
            Ok(AssertionOk)
          }),
        ]),
      ])
      |> runner.before_all_suites(fn(_suites) {
        start_linked_crash()
        Ok(Nil)
      })
      |> run_builder_bounded
      |> should
      |> be_equal(
        SandboxCompleted(
          RunSummary(tests: [#("a", Passed, [])], teardown_failures: [
            ScopeLost(set_up: BeforeAllSuitesHook, scope: [], reason: "Boom"),
          ]),
        ),
      )
      |> or_fail_with(
        "the death of the before_all_suites process should be reported",
      )
    }),

    it("the suites that have not started in a lost run do not run", fn() {
      let reports = process.new_subject()
      runner.new([
        describe("first", [
          it("a", fn() {
            process.sleep(30)
            Ok(AssertionOk)
          }),
        ]),
        describe("second", [
          it("b", fn() {
            process.send(reports, "b ran")
            Ok(AssertionOk)
          }),
        ]),
      ])
      |> runner.before_all_suites(fn(_suites) {
        start_linked_crash()
        Ok(Nil)
      })
      |> runner.after_all_suites(fn(_suites) {
        process.send(reports, "after_all_suites ran")
        Ok(Nil)
      })
      |> run_builder_bounded
      |> result_and_report(reports)
      |> should
      |> be_equal(#(
        SandboxCompleted(
          RunSummary(
            tests: [
              #("a", Passed, []),
              #("b", SetupFailed, [
                #("before_all_suites", "before_all_suites process exited: Boom"),
              ]),
            ],
            teardown_failures: [
              ScopeLost(set_up: BeforeAllSuitesHook, scope: [], reason: "Boom"),
            ],
          ),
        ),
        Ok("after_all_suites ran"),
      ))
      |> or_fail_with("the second suite should not run in a lost run scope")
    }),

    it("a lost suite scope without after_each_suite is reported", fn() {
      runner.new([
        describe("suite", [
          it("a", fn() {
            process.sleep(30)
            Ok(AssertionOk)
          }),
        ]),
      ])
      |> runner.before_each_suite(fn(_suite) {
        start_linked_crash()
        Ok(Nil)
      })
      |> run_builder_bounded
      |> should
      |> be_equal(
        SandboxCompleted(
          RunSummary(tests: [#("a", Passed, [])], teardown_failures: [
            ScopeLost(
              set_up: BeforeEachSuiteHook,
              scope: ["suite"],
              reason: "Boom",
            ),
          ]),
        ),
      )
      |> or_fail_with("a lost suite scope should be reported")
    }),

    it("a lost suite scope runs after_each_suite in a new process", fn() {
      let reports = process.new_subject()
      runner.new([
        describe("suite", [
          it("a", fn() {
            process.sleep(30)
            Ok(AssertionOk)
          }),
        ]),
      ])
      |> runner.before_each_suite(fn(_suite) {
        start_linked_crash()
        Ok(Nil)
      })
      |> runner.after_each_suite(fn(_suite) {
        process.send(reports, "after_each_suite ran")
        Ok(Nil)
      })
      |> run_builder_bounded
      |> result_and_report(reports)
      |> should
      |> be_equal(#(
        SandboxCompleted(
          RunSummary(tests: [#("a", Passed, [])], teardown_failures: [
            ScopeLost(
              set_up: BeforeEachSuiteHook,
              scope: ["suite"],
              reason: "Boom",
            ),
          ]),
        ),
        Ok("after_each_suite ran"),
      ))
      |> or_fail_with("after_each_suite should run after the scope is lost")
    }),

    it("an after_all_suites hook that crashes is a tear-down failure", fn() {
      runner.new([describe("suite", [it("a", passing_test)])])
      |> runner.after_all_suites(fn(_suites) { erlang_error(boom()) })
      |> runner.run()
      |> types.report_teardown_failures
      |> should
      |> be_equal([
        TeardownFailure(
          hook: AfterAllSuitesHook,
          scope: [],
          message: "hook crashed: error:boom",
        ),
      ])
      |> or_fail_with(
        "a crash in after_all_suites should be a tear-down failure",
      )
    }),
  ])
}

/// The context of the pool group: no pool before `before_all` runs.
type PoolContext {
  NoPool
  Pool(pid: Pid)
}

@external(erlang, "dream_test_hook_resource_test_ffi", "new_named_table")
fn new_named_table(name: Atom) -> Nil

@external(erlang, "dream_test_hook_resource_test_ffi", "table_exists")
fn table_exists(name: Atom) -> Bool

@external(erlang, "dream_test_hook_resource_test_ffi", "delete_table")
fn delete_table(name: Atom) -> Nil

@external(erlang, "erlang", "error")
fn erlang_error(reason: Atom) -> a

fn boom() -> Atom {
  atom.create("boom")
}

/// Start a pool the way a user does: a supervisor that links to the caller
/// and traps exits, so it stops when the caller stops.
fn start_pool() -> Result(Pid, String) {
  case
    static_supervisor.new(static_supervisor.OneForOne)
    |> static_supervisor.start
  {
    Ok(actor.Started(pid: pid, data: _supervisor)) -> Ok(pid)
    Error(_error) -> Error("the pool did not start")
  }
}

fn start_pool_in_context(_context: PoolContext) -> Result(PoolContext, String) {
  case start_pool() {
    Ok(pid) -> Ok(Pool(pid))
    Error(message) -> Error(message)
  }
}

fn stop_pool_in_context(context: PoolContext) -> Result(Nil, String) {
  case context {
    NoPool -> Error("no pool to stop")
    Pool(pid) -> {
      process.unlink(pid)
      process.kill(pid)
      Ok(Nil)
    }
  }
}

/// Wait a short time first, so that a pool that dies with the process that
/// started it is gone before the check.
fn pool_in_context_is_alive(
  context: PoolContext,
) -> Result(AssertionResult, String) {
  process.sleep(100)
  case context {
    NoPool -> Error("before_all gave no pool")
    Pool(pid) ->
      process.is_alive(pid)
      |> should
      |> be_equal(True)
      |> or_fail_with("the pool should be alive")
  }
}

fn start_named_pool(name: Name(Nil)) -> Result(Nil, String) {
  case start_pool() {
    Ok(pid) -> register(pid, name)
    Error(message) -> Error(message)
  }
}

fn register(pid: Pid, name: Name(Nil)) -> Result(Nil, String) {
  case process.register(pid, name) {
    Ok(Nil) -> Ok(Nil)
    Error(Nil) -> Error("the pool name is taken")
  }
}

fn stop_named_pool(name: Name(Nil)) -> Result(Nil, String) {
  case process.named(name) {
    Ok(pid) -> {
      process.unlink(pid)
      process.kill(pid)
      Ok(Nil)
    }
    Error(Nil) -> Error("no pool to stop")
  }
}

fn named_pool_is_alive(name: Name(Nil)) -> Result(AssertionResult, String) {
  process.sleep(100)
  process.named(name)
  |> result.map(process.is_alive)
  |> should
  |> be_equal(Ok(True))
  |> or_fail_with("the pool should be alive")
}

fn make_table(name: Atom) -> Result(Atom, String) {
  new_named_table(name)
  Ok(name)
}

fn remove_table(name: Atom) -> Result(Nil, String) {
  delete_table(name)
  Ok(Nil)
}

fn table_in_context_exists(name: Atom) -> Result(AssertionResult, String) {
  process.sleep(100)
  table_exists(name)
  |> should
  |> be_equal(True)
  |> or_fail_with("the ETS table should exist")
}

/// The tests and tear-down failures of a run, in a form that a sandbox
/// can return.
type RunSummary {
  RunSummary(
    tests: List(#(String, Status, List(#(String, String)))),
    teardown_failures: List(types.TeardownFailure),
  )
}

fn hang() -> a {
  process.sleep_forever()
  hang()
}

fn kill_self() -> a {
  process.kill(process.self())
  hang()
}

@external(erlang, "dream_test_hook_resource_test_ffi", "start_linked_crash")
fn start_linked_crash() -> Nil

/// Run a builder with a 50ms default timeout in a sandbox of 2 seconds, so
/// a hook that never returns fails the test instead of the whole run.
fn run_builder_bounded(
  builder: runner.RunBuilder(context),
) -> SandboxResult(RunSummary) {
  sandbox.run_isolated(
    SandboxConfig(timeout_ms: 2000, show_crash_reports: False),
    run_with_short_timeout,
    builder,
  )
}

fn run_bounded(suite: types.TestSuite(context)) -> SandboxResult(RunSummary) {
  run_builder_bounded(runner.new([suite]))
}

fn run_with_short_timeout(builder: runner.RunBuilder(context)) -> RunSummary {
  let report =
    builder
    |> runner.default_timeout_ms(50)
    |> runner.silent()
    |> runner.run()
  RunSummary(
    tests: failures(types.report_tests(report)),
    teardown_failures: types.report_teardown_failures(report),
  )
}

/// The result of a run and the first report that a hook sent, or
/// `Error(Nil)` when no hook sent one.
fn result_and_report(
  result: SandboxResult(RunSummary),
  reports: process.Subject(report),
) -> #(SandboxResult(RunSummary), Result(report, Nil)) {
  #(result, process.receive(reports, 0))
}

fn passing_test() -> Result(AssertionResult, String) {
  Ok(AssertionOk)
}

fn run_suite(suite: types.TestSuite(context)) -> List(TestResult) {
  runner.new([suite])
  |> runner.run()
  |> types.report_tests
}

fn statuses(results: List(TestResult)) -> List(#(String, Status)) {
  list.map(results, fn(result) { #(result.name, result.status) })
}

fn failures(
  results: List(TestResult),
) -> List(#(String, Status, List(#(String, String)))) {
  list.map(results, fn(result) {
    #(
      result.name,
      result.status,
      list.map(result.failures, fn(failure) {
        let AssertionFailure(operator: operator, message: message, payload: _) =
          failure
        #(operator, message)
      }),
    )
  })
}
