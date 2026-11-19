import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/parallel.{
  type OuterSetup, type RunRootParallelWithReporterResult, SetupRunning,
  SetupStopped,
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
  describe("dream_test/parallel outer set-ups", [
    it("a stopped outer set-up gives SetupFailed to each test", fn() {
      let reports = process.new_subject()
      types.root("suite", Nil, [
        unit.before_all(fn() {
          process.send(reports, "before_all ran")
          Ok(Nil)
        }),
        it("a", passing_test),
        unit.group("inner", [it("b", passing_test)]),
      ])
      |> run_in_setups([
        SetupStopped(
          set_up: BeforeAllSuitesHook,
          groups: [],
          reason: "Boom",
          not_run: [["first", "z"]],
        ),
      ])
      |> summary
      |> with_report(reports)
      |> should
      |> be_equal(#(
        Summary(
          tests: [
            #("a", SetupFailed, [
              #(
                "before_all_suites",
                "not run: the set-up from before_all_suites stopped (Boom)",
              ),
            ]),
            #("b", SetupFailed, [
              #(
                "before_all_suites",
                "not run: the set-up from before_all_suites stopped (Boom)",
              ),
            ]),
          ],
          setups: [
            #(
              BeforeAllSuitesHook,
              Stopped("Boom", [
                ["first", "z"],
                ["suite", "a"],
                ["suite", "inner", "b"],
              ]),
            ),
          ],
        ),
        Error(Nil),
      ))
      |> or_fail_with("no hook or test should run after the set-up stopped")
    }),

    it("a set-up whose check gives an error is stopped", fn() {
      types.root("suite", Nil, [it("a", passing_test)])
      |> run_in_setups([
        SetupRunning(
          set_up: BeforeEachSuiteHook,
          groups: ["suite"],
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
                "not run: the set-up from before_each_suite in \"suite\" stopped (Boom)",
              ),
            ]),
          ],
          setups: [#(BeforeEachSuiteHook, Stopped("Boom", [["suite", "a"]]))],
        ),
      )
      |> or_fail_with("a failed check should make the set-up stopped")
    }),

    it("a scope whose check gives Ok stays alive and its tests run", fn() {
      types.root("suite", Nil, [it("a", passing_test)])
      |> run_in_setups([
        SetupRunning(set_up: BeforeAllSuitesHook, groups: [], check_owner: fn() {
          Ok(Nil)
        }),
      ])
      |> summary
      |> should
      |> be_equal(
        Summary(tests: [#("a", Passed, [])], setups: [
          #(BeforeAllSuitesHook, Running),
        ]),
      )
      |> or_fail_with("the test should run while the scope is alive")
    }),

    it("the outermost stopped set-up is the failure of a test", fn() {
      types.root("suite", Nil, [it("a", passing_test)])
      |> run_in_setups([
        SetupStopped(
          set_up: BeforeAllSuitesHook,
          groups: [],
          reason: "outer",
          not_run: [],
        ),
        SetupStopped(
          set_up: BeforeEachSuiteHook,
          groups: ["suite"],
          reason: "inner",
          not_run: [],
        ),
      ])
      |> summary
      |> should
      |> be_equal(
        Summary(
          tests: [
            #("a", SetupFailed, [
              #(
                "before_all_suites",
                "not run: the set-up from before_all_suites stopped (outer)",
              ),
            ]),
          ],
          setups: [
            #(BeforeAllSuitesHook, Stopped("outer", [["suite", "a"]])),
            #(BeforeEachSuiteHook, Stopped("inner", [])),
          ],
        ),
      )
      |> or_fail_with("the run scope should be the failure")
    }),

    it(
      "a set-up that stops while the tests run stops the tests not started",
      fn() {
        let owner = process.spawn_unlinked(fn() { process.sleep_forever() })
        let monitor = process.monitor(owner)
        types.root("suite", Nil, [
          it("a", fn() {
            kill_and_wait(owner)
            Ok(AssertionOk)
          }),
          it("b", passing_test),
        ])
        |> run_with_concurrency_one([
          SetupRunning(
            set_up: BeforeAllSuitesHook,
            groups: [],
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
                #(
                  "before_all_suites",
                  "not run: the set-up from before_all_suites stopped (killed)",
                ),
              ]),
            ],
            setups: [
              #(BeforeAllSuitesHook, Stopped("killed", [["suite", "b"]])),
            ],
          ),
        )
        |> or_fail_with("b should not start after the set-up stopped")
      },
    ),
  ])
}

/// What a test sees of the result: each test, and each outer set-up.
type Summary {
  Summary(
    tests: List(#(String, Status, List(#(String, String)))),
    setups: List(#(types.SetUpHook, SetupState)),
  )
}

type SetupState {
  Running
  Stopped(reason: String, not_run: List(List(String)))
}

fn run_in_setups(
  suite: types.Root(Nil),
  setups: List(OuterSetup),
) -> RunRootParallelWithReporterResult {
  run_with_config(suite, parallel.default_config(), setups)
}

fn run_with_concurrency_one(
  suite: types.Root(Nil),
  setups: List(OuterSetup),
) -> RunRootParallelWithReporterResult {
  run_with_config(
    suite,
    parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 1000),
    setups,
  )
}

fn run_with_config(
  suite: types.Root(Nil),
  config: parallel.ParallelConfig,
  setups: List(OuterSetup),
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
      outer_setups: setups,
    ),
  )
}

fn summary(result: RunRootParallelWithReporterResult) -> Summary {
  Summary(
    tests: list.map(result.results, test_summary),
    setups: list.map(result.outer_setups, setup_summary),
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

fn setup_summary(setup: OuterSetup) -> #(types.SetUpHook, SetupState) {
  case setup {
    SetupRunning(set_up: set_up, groups: _, check_owner: _) -> #(
      set_up,
      Running,
    )
    SetupStopped(set_up: set_up, groups: _, reason: reason, not_run: not_run) -> #(
      set_up,
      Stopped(reason, not_run),
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

/// Kill a process and wait until it has exited.
fn kill_and_wait(pid: process.Pid) -> Nil {
  let monitor = process.monitor(pid)
  process.kill(pid)
  process.new_selector()
  |> process.select_specific_monitor(monitor, fn(_down) { Nil })
  |> process.selector_receive_forever
}
