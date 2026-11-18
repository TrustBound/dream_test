import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/parallel.{
  type EnclosingScope, type RunRootParallelWithReporterResult,
  EnclosingScopeAlive, EnclosingScopeLost,
}
import dream_test/sandbox
import dream_test/types.{
  type AssertionResult, type Status, type TestResult, AssertionOk,
  BeforeAllSuitesHook, BeforeEachSuiteHook, Passed, SetupFailed,
}
import dream_test/unit.{describe, it}
import gleam/erlang/process
import gleam/list
import gleam/option.{None}

pub fn tests() {
  describe("dream_test/parallel enclosing scopes", [
    it("a lost enclosing scope gives SetupFailed to each test", fn() {
      let reports = process.new_subject()
      describe("suite", [
        unit.before_all(fn() {
          process.send(reports, "before_all ran")
          Ok(Nil)
        }),
        it("a", passing_test),
        unit.group("inner", [it("b", passing_test)]),
      ])
      |> run_in_scopes([
        EnclosingScopeLost(
          set_up: BeforeAllSuitesHook,
          scope: [],
          reason: "Boom",
        ),
      ])
      |> summary
      |> with_report(reports)
      |> should
      |> be_equal(#(
        Summary(
          tests: [
            #("a", SetupFailed, [
              #("before_all_suites", "before_all_suites process exited: Boom"),
            ]),
            #("b", SetupFailed, [
              #("before_all_suites", "before_all_suites process exited: Boom"),
            ]),
          ],
          scopes: [#(BeforeAllSuitesHook, Lost("Boom"))],
        ),
        Error(Nil),
      ))
      |> or_fail_with("no hook or test should run in a lost scope")
    }),

    it("a scope whose check gives an error is lost", fn() {
      describe("suite", [it("a", passing_test)])
      |> run_in_scopes([
        EnclosingScopeAlive(
          set_up: BeforeEachSuiteHook,
          scope: ["suite"],
          check_owner: fn() { Error("Boom") },
        ),
      ])
      |> summary
      |> should
      |> be_equal(
        Summary(
          tests: [
            #("a", SetupFailed, [
              #(
                "before_each_suite",
                "before_each_suite process exited in suite: Boom",
              ),
            ]),
          ],
          scopes: [#(BeforeEachSuiteHook, Lost("Boom"))],
        ),
      )
      |> or_fail_with("a failed check should make the scope lost")
    }),

    it("a scope whose check gives Ok stays alive and its tests run", fn() {
      describe("suite", [it("a", passing_test)])
      |> run_in_scopes([
        EnclosingScopeAlive(
          set_up: BeforeAllSuitesHook,
          scope: [],
          check_owner: fn() { Ok(Nil) },
        ),
      ])
      |> summary
      |> should
      |> be_equal(
        Summary(tests: [#("a", Passed, [])], scopes: [
          #(BeforeAllSuitesHook, Alive),
        ]),
      )
      |> or_fail_with("the test should run while the scope is alive")
    }),

    it("the outermost lost scope is the failure of a test", fn() {
      describe("suite", [it("a", passing_test)])
      |> run_in_scopes([
        EnclosingScopeLost(
          set_up: BeforeAllSuitesHook,
          scope: [],
          reason: "outer",
        ),
        EnclosingScopeLost(
          set_up: BeforeEachSuiteHook,
          scope: ["suite"],
          reason: "inner",
        ),
      ])
      |> summary
      |> should
      |> be_equal(
        Summary(
          tests: [
            #("a", SetupFailed, [
              #("before_all_suites", "before_all_suites process exited: outer"),
            ]),
          ],
          scopes: [
            #(BeforeAllSuitesHook, Lost("outer")),
            #(BeforeEachSuiteHook, Lost("inner")),
          ],
        ),
      )
      |> or_fail_with("the run scope should be the failure")
    }),

    it("a scope lost while the tests run stops the tests not started", fn() {
      let owner = process.spawn_unlinked(fn() { process.sleep_forever() })
      let monitor = process.monitor(owner)
      describe("suite", [
        it("a", fn() {
          process.kill(owner)
          process.sleep(10)
          Ok(AssertionOk)
        }),
        it("b", passing_test),
      ])
      |> run_with_concurrency_one([
        EnclosingScopeAlive(
          set_up: BeforeAllSuitesHook,
          scope: [],
          check_owner: fn() { check_process(monitor) },
        ),
      ])
      |> summary
      |> should
      |> be_equal(
        Summary(
          tests: [
            #("a", Passed, []),
            #("b", SetupFailed, [
              #("before_all_suites", "before_all_suites process exited: killed"),
            ]),
          ],
          scopes: [#(BeforeAllSuitesHook, Lost("killed"))],
        ),
      )
      |> or_fail_with("b should not start after the scope is lost")
    }),
  ])
}

/// What a test sees of the result: each test, and each enclosing scope.
type Summary {
  Summary(
    tests: List(#(String, Status, List(#(String, String)))),
    scopes: List(#(types.SetUpHook, ScopeState)),
  )
}

type ScopeState {
  Alive
  Lost(reason: String)
}

fn run_in_scopes(
  suite: types.TestSuite(Nil),
  scopes: List(EnclosingScope),
) -> RunRootParallelWithReporterResult {
  run_with_config(suite, parallel.default_config(), scopes)
}

fn run_with_concurrency_one(
  suite: types.TestSuite(Nil),
  scopes: List(EnclosingScope),
) -> RunRootParallelWithReporterResult {
  run_with_config(
    suite,
    parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 1000),
    scopes,
  )
}

fn run_with_config(
  suite: types.TestSuite(Nil),
  config: parallel.ParallelConfig,
  scopes: List(EnclosingScope),
) -> RunRootParallelWithReporterResult {
  parallel.run_root_parallel_with_reporter(
    parallel.RunRootParallelWithReporterConfig(
      config: config,
      suite: suite,
      progress_reporter: None,
      write: ignore,
      total: 0,
      completed: 0,
      runner_before_each_test: [],
      runner_after_each_test: [],
      enclosing_scopes: scopes,
    ),
  )
}

fn summary(result: RunRootParallelWithReporterResult) -> Summary {
  Summary(
    tests: list.map(result.results, test_summary),
    scopes: list.map(result.enclosing_scopes, scope_summary),
  )
}

fn test_summary(
  result: TestResult,
) -> #(String, Status, List(#(String, String))) {
  #(
    result.name,
    result.status,
    list.map(result.failures, fn(failure) {
      #(failure.operator, failure.message)
    }),
  )
}

fn scope_summary(scope: EnclosingScope) -> #(types.SetUpHook, ScopeState) {
  case scope {
    EnclosingScopeAlive(set_up: set_up, scope: _, check_owner: _) -> #(
      set_up,
      Alive,
    )
    EnclosingScopeLost(set_up: set_up, scope: _, reason: reason) -> #(
      set_up,
      Lost(reason),
    )
  }
}

fn with_report(
  value: value,
  reports: process.Subject(report),
) -> #(value, Result(report, Nil)) {
  #(value, process.receive(reports, 0))
}

/// `Ok(Nil)` while the monitored process is alive, or `Error(reason)` with
/// its exit reason after it stopped.
fn check_process(monitor: process.Monitor) -> Result(Nil, String) {
  let selector =
    process.new_selector()
    |> process.select_specific_monitor(monitor, down_reason)
  case process.selector_receive(selector, 0) {
    Ok(reason) -> Error(reason)
    Error(Nil) -> Ok(Nil)
  }
}

fn down_reason(down: process.Down) -> String {
  sandbox.format_exit_reason(down.reason)
}

fn passing_test() -> Result(AssertionResult, String) {
  Ok(AssertionOk)
}

fn ignore(_text: String) -> Nil {
  Nil
}
