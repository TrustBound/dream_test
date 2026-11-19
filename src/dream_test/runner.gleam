//// Test runner for dream_test.
////
//// This module provides a **pipe-friendly builder API** for running suites and
//// collecting `dream_test/types.TestResult` values.
////
//// ## When should I use this?
////
//// - Always: the runner is how you execute suites built with `dream_test/unit`,
////   `dream_test/unit_context`, or `dream_test/gherkin/feature`.
////
//// ## What does the runner do?
////
//// - Runs groups sequentially, tests in parallel (bounded by `max_concurrency`)
//// - Sandboxes tests and hooks (timeouts + crash isolation)
//// - Optionally drives an event-based reporter
////
//// ## Example
////
//// ```gleam
//// import dream_test/matchers.{be_equal, or_fail_with, should}
//// import dream_test/parallel
//// import dream_test/reporters/bdd
//// import dream_test/reporters/progress
//// import dream_test/runner
//// import dream_test/unit.{describe, it}
////
//// pub fn tests() {
////   describe("Example", [
////     it("works", fn() {
////       1 + 1
////       |> should
////       |> be_equal(2)
////       |> or_fail_with("math should work")
////     }),
////   ])
//// }
////
//// pub fn main() {
////   let db_config =
////     parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 60_000)
////
////   runner.new([])
////   |> runner.add_suites([tests()])
////   |> runner.add_suites_with_config(db_config, [db_tests()])
////   |> runner.progress_reporter(progress.new())
////   |> runner.results_reporters([bdd.new()])
////   |> runner.exit_on_failure()
////   |> runner.run()
//// }
//// ```

import dream_test/coverage.{type CoverageConfig, type CoverageSession}
import dream_test/coverage/report.{type CoverageReport}
import dream_test/parallel
import dream_test/reporters/bdd
import dream_test/reporters/coverage as coverage_reporter
import dream_test/reporters/json
import dream_test/reporters/progress
import dream_test/reporters/summary
import dream_test/reporters/types as reporter_types
import dream_test/sandbox.{
  type SandboxResult, type SetupProcess, type SetupProcessResult,
  SandboxCompleted, SandboxConfig, SandboxCrashed, SandboxTimedOut,
  SetupProcessCaught, SetupProcessExited, SetupProcessLost, SetupProcessReturned,
  SetupProcessTimedOut,
}
import dream_test/suite.{type TestSuite}
import dream_test/types.{
  type AssertionFailure, type RunReport, type SetUpHook, type TeardownFailure,
  type TeardownHook, type TestResult, AfterAllSuitesHook, AfterEachSuiteHook,
  BeforeAllSuitesHook, BeforeEachSuiteHook, Passed, SetupFailed, SetupStopped,
  TeardownFailure,
}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// Lightweight information about a test, used for filtering what runs.
///
/// See `dream_test/types.TestInfo` for fields and details.
pub type TestInfo =
  types.TestInfo

/// Builder for configuring and running suites.
///
/// You typically construct one with `runner.new(...)` and then pipe through
/// configuration helpers like `runner.progress_reporter`, `runner.results_reporters`,
/// `runner.max_concurrency`, etc.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit.{describe, it}
/// import gleam/io
///
/// pub fn tests() {
///   describe("Example", [
///     it("works", fn() {
///       1 + 1
///       |> should
///       |> be_equal(2)
///       |> or_fail_with("math should work")
///     }),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
pub opaque type RunBuilder {
  RunBuilder(
    suite_runs: List(SuiteRun),
    config: parallel.ParallelConfig,
    test_filter: Option(fn(TestInfo) -> Bool),
    should_exit_on_failure: Bool,
    progress_reporter: Option(progress.ProgressReporter),
    results_reporters: List(reporter_types.ResultsReporter),
    output: Option(Output),
    coverage: CoverageRequest,
    runner_before_each_test: List(fn(types.TestInfo) -> Result(Nil, String)),
    runner_after_each_test: List(fn(types.TestInfo) -> Result(Nil, String)),
    runner_before_each_suite: List(fn(types.SuiteInfo) -> Result(Nil, String)),
    runner_after_each_suite: List(fn(types.SuiteInfo) -> Result(Nil, String)),
    runner_before_all_suites: List(
      fn(List(types.SuiteInfo)) -> Result(Nil, String),
    ),
    runner_after_all_suites: List(
      fn(List(types.SuiteInfo)) -> Result(Nil, String),
    ),
  )
}

/// A suite of the run, with its config and the tests of it that run.
type SuiteRun {
  SuiteRun(
    suite: TestSuite,
    config_override: Option(parallel.ParallelConfig),
    tests: List(types.TestInfo),
  )
}

/// Output sinks used by `runner.run()`.
///
/// Reporters write to `out`. Runner-internal errors (not test failures) may be
/// written to `error` as well.
pub type Output {
  Output(out: fn(String) -> Nil, error: fn(String) -> Nil)
}

/// Create a new runner builder for a list of suites.
///
/// Every suite has the type `TestSuite`, whatever the context of its tests,
/// so suites from `dream_test/unit`, `dream_test/unit_context` and Gherkin
/// go in one list.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit.{describe, it}
/// import gleam/io
///
/// pub fn tests() {
///   describe("Example", [
///     it("works", fn() {
///       1 + 1
///       |> should
///       |> be_equal(2)
///       |> or_fail_with("math should work")
///     }),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// ## Parameters
///
/// - `suites`: the test suites you want to run (often just `[tests()]`)
///
/// ## Returns
///
/// A `RunBuilder` you can pipe through configuration helpers and finally
/// `runner.run()`.
pub fn new(suites suites: List(TestSuite)) -> RunBuilder {
  let config = parallel.default_config()
  RunBuilder(
    suite_runs: suites_to_suite_runs_default(suites, []),
    config: config,
    test_filter: None,
    should_exit_on_failure: False,
    progress_reporter: None,
    results_reporters: [],
    output: None,
    coverage: NoCoverage,
    runner_before_each_test: [],
    runner_after_each_test: [],
    runner_before_each_suite: [],
    runner_after_each_suite: [],
    runner_before_all_suites: [],
    runner_after_all_suites: [],
  )
}

/// Append suites to the run, using the builder’s current execution config.
///
/// This is useful when you want to build up your suite list incrementally
/// (especially when some suites need a different execution config).
///
/// Suites added with `add_suites` will run using the runner’s current execution
/// config (configured via `max_concurrency` / `default_timeout_ms`).
///
/// ## Example
///
/// ```gleam
/// runner.new([])
/// |> runner.add_suites([unit_suite()])
/// |> runner.add_suites([integration_suite()])
/// |> runner.run()
/// ```
pub fn add_suites(
  builder builder: RunBuilder,
  suites suites: List(TestSuite),
) -> RunBuilder {
  let appended = append_suite_runs_default(builder.suite_runs, suites)
  RunBuilder(..builder, suite_runs: appended)
}

/// Append suites to the run, using an explicit execution config override.
///
/// This lets you run suites with different concurrency/timeout policies in a
/// single runner invocation (for example: DB suites sequential, unit suites
/// parallel).
///
/// The override applies only to the suites added by this call. Reporting, output,
/// filtering, and exit behavior remain global runner settings.
///
/// ## Example
///
/// ```gleam
/// import dream_test/parallel
///
/// let db_config =
///   parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 60_000)
///
/// runner.new([])
/// |> runner.add_suites([unit_suite()])
/// |> runner.add_suites_with_config(db_config, [db_suite()])
/// |> runner.max_concurrency(50)
/// |> runner.default_timeout_ms(5_000)
/// |> runner.run()
/// ```
pub fn add_suites_with_config(
  builder builder: RunBuilder,
  config config: parallel.ParallelConfig,
  suites suites: List(TestSuite),
) -> RunBuilder {
  let appended =
    append_suite_runs_with_override(builder.suite_runs, config, suites)
  RunBuilder(..builder, suite_runs: appended)
}

/// Set the maximum number of concurrently running tests.
///
/// - `1` gives fully sequential test execution.
/// - Higher values increase parallelism.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit.{describe, it}
/// import gleam/io
///
/// pub fn tests() {
///   describe("Sequential tests", [
///     it("first test", fn() {
///       // When tests share external resources, run them sequentially
///       1 + 1
///       |> should
///       |> be_equal(2)
///       |> or_fail_with("Math works")
///     }),
///     it("second test", fn() {
///       2 + 2
///       |> should
///       |> be_equal(4)
///       |> or_fail_with("Math still works")
///     }),
///   ])
/// }
///
/// pub fn main() {
///   // Sequential execution for tests with shared state
///   runner.new([tests()])
///   |> runner.max_concurrency(1)
///   |> runner.default_timeout_ms(30_000)
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// ## Parameters
///
/// - `builder`: the runner builder you’re configuring
/// - `max`: maximum number of concurrently running tests (use `1` for fully sequential)
///
/// ## Returns
///
/// The updated `RunBuilder`.
pub fn max_concurrency(
  builder builder: RunBuilder,
  max max: Int,
) -> RunBuilder {
  let parallel.ParallelConfig(max_concurrency: _, default_timeout_ms: timeout) =
    builder.config
  RunBuilder(
    ..builder,
    config: parallel.ParallelConfig(
      max_concurrency: max,
      default_timeout_ms: timeout,
    ),
  )
}

/// Set the default timeout (milliseconds) applied to tests without an explicit timeout.
///
/// The timeout counts from the start of the test body. A body that runs
/// longer is killed and reported as `TimedOut`, in parallel and in
/// sequential runs. Each hook gets the same timeout on its own. The
/// `render` function of each `reporter_types.Custom` results reporter also
/// gets this timeout.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit.{describe, it}
/// import gleam/io
///
/// pub fn tests() {
///   describe("Runner config demo", [
///     it("runs with custom config", fn() {
///       1 + 1
///       |> should
///       |> be_equal(2)
///       |> or_fail_with("Math works")
///     }),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.max_concurrency(8)
///   |> runner.default_timeout_ms(10_000)
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// ## Parameters
///
/// - `builder`: the runner builder you’re configuring
/// - `timeout_ms`: timeout in milliseconds applied to tests without an explicit timeout
///
/// ## Returns
///
/// The updated `RunBuilder`.
pub fn default_timeout_ms(
  builder builder: RunBuilder,
  timeout_ms timeout_ms: Int,
) -> RunBuilder {
  let parallel.ParallelConfig(max_concurrency: max, default_timeout_ms: _) =
    builder.config
  RunBuilder(
    ..builder,
    config: parallel.ParallelConfig(
      max_concurrency: max,
      default_timeout_ms: timeout_ms,
    ),
  )
}

/// Exit the BEAM with status 1 if the run fails.
///
/// The run fails in five cases (see "Exit status" in
/// `documentation/07-runner-and-execution.md`):
///
/// 1. A test is `Failed`, `TimedOut` or `SetupFailed`.
/// 2. A tear-down hook failed, also when every test passed.
/// 3. A set-up stopped (`types.SetupStopped`).
/// 4. The `render` function of a `reporter_types.Custom` reporter crashed.
/// 5. Coverage failed.
///
/// `types.failed` is `True` in the first four cases.
///
/// Useful for CI pipelines.
///
/// When the run fails, `runner.run` first writes all its output, the
/// reports and the coverage files. Then it ends the program with exit
/// status 1 and does not return, so no code after `runner.run` runs. A
/// second `runner.run` in the same `main` does not start. This is the same
/// on every Gleam version, for `gleam test` and for `gleam run`.
///
/// To end the program, `runner.run` asks the BEAM to stop with status 1
/// (`init:stop(1)`) and waits until the BEAM stops. The BEAM shuts down
/// cleanly: the output is written, and applications stop.
///
/// When the run passes, `runner.run` returns the report.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit.{describe, it}
/// import gleam/io
///
/// pub fn tests() {
///   describe("Example", [
///     it("works", fn() {
///       1 + 1
///       |> should
///       |> be_equal(2)
///       |> or_fail_with("math should work")
///     }),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// ## Parameters
///
/// - `builder`: the runner builder you’re configuring
///
/// ## Returns
///
/// The updated `RunBuilder`.
pub fn exit_on_failure(builder builder: RunBuilder) -> RunBuilder {
  RunBuilder(..builder, should_exit_on_failure: True)
}

/// Attach a progress reporter (live output during the run).
///
/// This reporter is driven by `TestFinished` events in completion order.
/// It is intended for a single in-place progress bar UI.
pub fn progress_reporter(
  builder builder: RunBuilder,
  reporter reporter: progress.ProgressReporter,
) -> RunBuilder {
  RunBuilder(..builder, progress_reporter: Some(reporter))
}

/// Attach results reporters (printed at the end, in the order provided).
///
/// Each results reporter gets the run report once, after the run ends. Its
/// tests are in traversal order, so the output is the same under parallel
/// execution.
pub fn results_reporters(
  builder builder: RunBuilder,
  reporters reporters: List(reporter_types.ResultsReporter),
) -> RunBuilder {
  RunBuilder(..builder, results_reporters: reporters)
}

/// Configure output sinks for `runner.run()`.
///
/// This is how you route reporter output (stdout vs stderr, capturing output in
/// tests, etc).
///
/// ## Example
///
/// ```gleam
/// import dream_test/runner
/// import gleam/io
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.output(runner.Output(out: io.print, error: io.eprint))
///   |> runner.run()
/// }
/// ```
pub fn output(
  builder builder: RunBuilder,
  output output: Output,
) -> RunBuilder {
  RunBuilder(..builder, output: Some(output))
}

/// Measure line coverage of the project's own `src` modules during the run.
///
/// Before any test runs, the runner gives every module built from the source
/// directory the native line counters of the BEAM (Erlang/OTP 27 or later
/// with the JIT). After the results reporters,
/// it prints a coverage table and writes an LCOV file. See
/// `dream_test/coverage` for the settings.
///
/// A coverage error (for example, a module without debug information) is
/// written to the error output. With `exit_on_failure`, it also makes the run
/// exit with status 1, so a broken coverage setup does not pass silently.
///
/// ## Example
///
/// ```gleam
/// import dream_test/coverage
/// import dream_test/reporters/bdd
/// import dream_test/runner
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.results_reporters([bdd.new()])
///   |> runner.coverage(coverage.new())
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
pub fn coverage(
  builder builder: RunBuilder,
  config config: CoverageConfig,
) -> RunBuilder {
  RunBuilder(..builder, coverage: AlwaysCoverage(config))
}

/// Measure line coverage only when the `DREAM_TEST_COVERAGE` environment
/// variable turns it on.
///
/// Use this to measure coverage in some runs (for example in CI) without a
/// change to your test `main`. The runner reads the variable when
/// `runner.run` starts:
///
/// | `DREAM_TEST_COVERAGE` | Result                         |
/// |-----------------------|--------------------------------|
/// | `1` or `true`         | coverage runs with `config`    |
/// | `0` or `false`        | no coverage                    |
/// | not set               | no coverage                    |
/// | any other value       | coverage error                 |
///
/// The values are exact and lowercase. Any other value, an empty value
/// included, is a coverage error (`coverage.InvalidEnvironmentValue`), so a
/// mistyped value does not turn coverage off silently. The error is written
/// to the error output, and with `exit_on_failure` the run exits with
/// status 1.
///
/// This call and `runner.coverage` set the same option, so the last call
/// wins.
///
/// ## Parameters
///
/// - `builder`: the run to configure
/// - `config`: the coverage settings to use when the variable turns
///   coverage on
///
/// ## Returns
///
/// The builder with coverage that depends on the environment.
///
/// ## Example
///
/// ```gleam
/// import dream_test/coverage
/// import dream_test/reporters/bdd
/// import dream_test/runner
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.results_reporters([bdd.new()])
///   |> runner.coverage_from_environment(coverage.new())
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// Then, in CI (GitHub Actions):
///
/// ```yaml
/// - run: gleam test
///   env:
///     DREAM_TEST_COVERAGE: "1"
/// ```
///
/// A local `gleam test` runs without coverage, and
/// `DREAM_TEST_COVERAGE=1 gleam test` runs with it.
pub fn coverage_from_environment(
  builder builder: RunBuilder,
  config config: CoverageConfig,
) -> RunBuilder {
  RunBuilder(..builder, coverage: CoverageFromEnvironment(config))
}

/// Disable all reporter output (still returns results from `runner.run()`).
///
/// A silent run drops normal output only. Errors still go to the standard
/// error stream, for example a `Results reporter failed` error or a coverage
/// error.
pub fn silent(builder builder: RunBuilder) -> RunBuilder {
  RunBuilder(..builder, output: Some(silent_output()))
}

/// Filter which tests are executed.
///
/// The predicate receives `TestInfo`: the test `name`, the names of its
/// `groups` from the outermost group, its `tags`, its `kind` and its
/// `source`. Tags include inherited group tags.
///
/// Groups with no selected tests in their entire subtree are skipped entirely,
/// including hooks.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner.{type TestInfo}
/// import dream_test/unit.{describe, it, with_tags}
/// import gleam/io
/// import gleam/list
///
/// pub fn tests() {
///   describe("Filtering tests", [
///     it("smoke", fn() {
///       1 + 1
///       |> should
///       |> be_equal(2)
///       |> or_fail_with("math should work")
///     })
///       |> with_tags(["smoke"]),
///     it("slow", fn() { Ok(succeed()) })
///       |> with_tags(["slow"]),
///   ])
/// }
///
/// pub fn only_smoke(info: TestInfo) -> Bool {
///   list.contains(info.tags, "smoke")
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.filter_tests(only_smoke)
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// ## Parameters
///
/// - `builder`: the runner builder you’re configuring
/// - `predicate`: function that decides whether a test should run
///
/// ## Returns
///
/// The updated `RunBuilder`.
pub fn filter_tests(
  builder builder: RunBuilder,
  predicate predicate: fn(TestInfo) -> Bool,
) -> RunBuilder {
  RunBuilder(..builder, test_filter: Some(predicate))
}

/// Register a runner-level hook that runs before each test.
///
/// The hook receives `types.TestInfo`. It runs in the process of the test,
/// before the `before_each` hooks, with the default timeout.
/// If it returns `Error("...")`, times out or crashes, the test is marked
/// `SetupFailed` and the test body does not run.
///
/// ## Example
///
/// ```gleam
/// import dream_test/runner
/// import dream_test/types.{type TestInfo}
/// import gleam/io
/// import gleam/string
///
/// fn log_test(info: TestInfo) -> Result(Nil, String) {
///   let name = string.join(types.full_name(info.groups, info.name), " > ")
///   io.println("starting " <> name)
///   Ok(Nil)
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.before_each_test(log_test)
///   |> runner.run()
/// }
/// ```
pub fn before_each_test(
  builder builder: RunBuilder,
  hook hook: fn(types.TestInfo) -> Result(Nil, String),
) -> RunBuilder {
  RunBuilder(
    ..builder,
    runner_before_each_test: list.append(builder.runner_before_each_test, [hook]),
  )
}

/// Register a runner-level hook that runs after each test.
///
/// The hook receives `types.TestInfo`. It runs in the process of the test,
/// after the body and the `after_each` hooks, with the default timeout. If
/// the body timed out or the test process stopped, it runs in a new process.
/// Every `after_each_test` hook
/// runs, also after one fails. If it returns `Error("...")` or crashes, the
/// status of the test does not change: the run report gets a
/// `types.TeardownFailure` with hook `AfterEachTestHook`, and the run fails.
pub fn after_each_test(
  builder builder: RunBuilder,
  hook hook: fn(types.TestInfo) -> Result(Nil, String),
) -> RunBuilder {
  RunBuilder(
    ..builder,
    runner_after_each_test: list.append(builder.runner_after_each_test, [hook]),
  )
}

/// Register a runner-level hook that runs before each suite.
///
/// The hook receives `types.SuiteInfo` for the suite about to run. It runs
/// in the setup process of the suite, so a resource that it starts lives
/// until the `after_each_suite` hooks of the suite end. It gets the default
/// timeout of the suite.
/// If it returns `Error("...")`, times out or crashes, all tests in that suite are
/// marked `SetupFailed`, the suite does not run, and `after_each_suite`
/// still runs.
///
/// The hook does not run for a suite that has no test after filtering.
pub fn before_each_suite(
  builder builder: RunBuilder,
  hook hook: fn(types.SuiteInfo) -> Result(Nil, String),
) -> RunBuilder {
  RunBuilder(
    ..builder,
    runner_before_each_suite: list.append(builder.runner_before_each_suite, [
      hook,
    ]),
  )
}

/// Register a runner-level hook that runs after each suite.
///
/// The hook receives `types.SuiteInfo` for the suite that just ran. It runs
/// in the setup process of the suite, with the default timeout of the
/// suite. Every `after_each_suite` hook runs, also after one fails. If it
/// returns `Error("...")`, times out or crashes, the
/// run report gets a `types.TeardownFailure` with hook `AfterEachSuiteHook`
/// and the suite name in `groups`, and the run fails.
///
/// The hook does not run for a suite that has no test after filtering.
pub fn after_each_suite(
  builder builder: RunBuilder,
  hook hook: fn(types.SuiteInfo) -> Result(Nil, String),
) -> RunBuilder {
  RunBuilder(
    ..builder,
    runner_after_each_suite: list.append(builder.runner_after_each_suite, [hook]),
  )
}

/// Register a runner-level hook that runs before all suites.
///
/// The hook receives the full list of `SuiteInfo` after filtering. It runs
/// in the setup process of the run, so a resource that it starts (for
/// example a pool that links to the caller) lives until `after_all_suites`
/// stops it. It gets the default timeout.
/// If it returns `Error("...")`, times out or crashes, all selected tests are marked
/// `SetupFailed`, no suite runs, and `after_all_suites` still runs.
///
/// The hook does not run when the run has no test after filtering.
pub fn before_all_suites(
  builder builder: RunBuilder,
  hook hook: fn(List(types.SuiteInfo)) -> Result(Nil, String),
) -> RunBuilder {
  RunBuilder(
    ..builder,
    runner_before_all_suites: list.append(builder.runner_before_all_suites, [
      hook,
    ]),
  )
}

/// Register a runner-level hook that runs after all suites.
///
/// The hook receives the full list of `SuiteInfo` after filtering. It runs
/// in the setup process of the run, with the default timeout. Every
/// `after_all_suites` hook runs, also after one fails. If it returns
/// `Error("...")`, times out or crashes, the
/// run report gets a `types.TeardownFailure` with hook `AfterAllSuitesHook`
/// and `groups: []`, and the run fails.
///
/// The hook does not run when the run has no test after filtering.
pub fn after_all_suites(
  builder builder: RunBuilder,
  hook hook: fn(List(types.SuiteInfo)) -> Result(Nil, String),
) -> RunBuilder {
  RunBuilder(
    ..builder,
    runner_after_all_suites: list.append(builder.runner_after_all_suites, [hook]),
  )
}

/// Run all suites and return a `types.RunReport`.
///
/// If a progress reporter is attached, the runner will emit progress output during
/// the run. Results reporters print at the end of the run.
///
/// With `exit_on_failure`, a failed run does not return: it writes all its
/// output and then ends the program with exit status 1.
///
/// The runner calls the `render` function of a `reporter_types.Custom`
/// reporter in a new process. When it does not return in the default
/// timeout of the run (`default_timeout_ms`), the runner stops it, and it
/// counts as a crash.
///
/// If the `render` function of a `reporter_types.Custom` reporter crashes,
/// the runner writes a `Results reporter failed` error to the error output
/// and goes on with the next reporter and with coverage. The error names
/// the position of the reporter in the list of `results_reporters`. The
/// first reporter is at position 1, and every reporter in the list counts.
/// The returned report has the crash (see `types.report_reporter_crashes`),
/// so `types.failed` is `True` for it. The reporters themselves get the
/// report without the crashes. With `exit_on_failure`, the crash
/// also ends the program with exit status 1.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit.{describe, it}
///
/// pub fn tests() {
///   describe("Example", [
///     it("works", fn() {
///       1 + 1
///       |> should
///       |> be_equal(2)
///       |> or_fail_with("math should work")
///     }),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// ## Parameters
///
/// - `builder`: the fully configured runner builder
///
/// ## Returns
///
/// A `types.RunReport`: the `TestResult` of each test, in deterministic
/// order, and the tear-down hooks that failed. Read it with
/// `types.report_tests` and `types.report_teardown_failures`, and check it
/// with `types.failed`. With `exit_on_failure`, the BEAM stops with status 1
/// when `types.failed(report)` is `True`, when a `reporter_types.Custom`
/// reporter crashes, or when coverage fails (a total or a file below a
/// minimum, or coverage that did not complete).
pub fn run(builder builder: RunBuilder) -> RunReport {
  let selected_runs = apply_test_filter(builder.suite_runs, builder.test_filter)
  let total = count_total_tests(selected_runs)
  let suite_runs_with_infos = suite_runs_with_infos(selected_runs, [])
  let suite_infos = list.map(suite_runs_with_infos, suite_info_of_pair)

  let output = case builder.output {
    Some(output) -> output
    None -> default_output()
  }

  let coverage_state = start_coverage(builder.coverage)

  let completed0 = 0
  let progress_reporter0 = builder.progress_reporter
  let completed1 = case progress_reporter0 {
    None -> completed0
    Some(progress_reporter) -> {
      write_progress_event(
        progress_reporter,
        progress.RunStartedProgress(total: total),
        output,
      )
      completed0
    }
  }

  let all_suites_timeout_ms = builder.config.default_timeout_ms
  let before_all_result =
    run_suite_level_hooks(
      SuiteSetUp(
        hooks: all_suites_hooks(selected_runs, builder.runner_before_all_suites),
        input: suite_infos,
        scope: [],
        timeout_ms: all_suites_timeout_ms,
      ),
      None,
    )

  let #(collected, completed2, all_suites_setup_process_after_run) = case
    before_all_result
  {
    SuiteSetUpRan(setup_process: all_suites_setup_process) ->
      run_suites_with_hooks(
        suite_runs_with_infos,
        builder.config,
        progress_reporter0,
        output,
        total,
        completed1,
        builder.runner_before_each_suite,
        builder.runner_after_each_suite,
        builder.runner_before_each_test,
        builder.runner_after_each_test,
        builder.test_filter,
        Collected(tests: [], teardown_failures: []),
        all_suites_setup_process,
      )
    SuiteSetUpFailed(setup_process: all_suites_setup_process, message: message) -> {
      let setup_failures =
        setup_failed_results_from_suites(
          suite_infos,
          "before_all_suites",
          message,
        )
      let completed_after_failures =
        emit_test_finished_progress_results(
          progress_reporter0,
          output,
          completed1,
          total,
          setup_failures,
        )
      #(
        Collected(tests: setup_failures, teardown_failures: []),
        completed_after_failures,
        alive_suite_setup_process(all_suites_setup_process),
      )
    }
  }

  let after_all_failures =
    finish_suite_scope(
      SuiteTearDown(
        hooks: all_suites_hooks(selected_runs, builder.runner_after_all_suites),
        input: suite_infos,
        scope: [],
        timeout_ms: all_suites_timeout_ms,
        hook_kind: AfterAllSuitesHook,
        set_up: BeforeAllSuitesHook,
      ),
      all_suites_setup_process_after_run,
    )

  let teardown_failures =
    list.append(collected.teardown_failures, after_all_failures)
  let report =
    types.run_report(
      tests: collected.tests,
      teardown_failures: teardown_failures,
      reporter_crashes: [],
    )

  let counts = summary.count(report)
  case progress_reporter0 {
    None -> Nil
    Some(progress_reporter) ->
      write_progress_event(
        progress_reporter,
        progress.RunFinishedProgress(
          completed: completed2,
          total: total,
          teardown_failures: counts.teardown_failed,
          setup_stopped: counts.setup_stopped,
        ),
        output,
      )
  }

  let report =
    types.run_report(
      tests: collected.tests,
      teardown_failures: teardown_failures,
      reporter_crashes: write_results_reporters(
        builder.results_reporters,
        report,
        output,
        builder.config.default_timeout_ms,
      ),
    )

  let coverage_succeeded =
    finish_coverage(
      coverage_state,
      output,
      run_outcome(report, builder.should_exit_on_failure),
    )

  maybe_exit_on_failure(
    builder.should_exit_on_failure,
    report,
    coverage_succeeded,
  )

  report
}

/// The test results and the tear-down failures of the suites that ran so
/// far, in the order of the run.
type Collected {
  Collected(tests: List(TestResult), teardown_failures: List(TeardownFailure))
}

/// Each suite run with the `SuiteInfo` of its suite, so the hooks of a
/// suite always get the info of the suite that runs.
fn suite_runs_with_infos(
  suite_runs: List(SuiteRun),
  acc_rev: List(#(SuiteRun, types.SuiteInfo)),
) -> List(#(SuiteRun, types.SuiteInfo)) {
  case suite_runs {
    [] -> list.reverse(acc_rev)
    [suite_run, ..rest] ->
      suite_runs_with_infos(rest, [
        #(suite_run, suite_info_from_suite_run(suite_run)),
        ..acc_rev
      ])
  }
}

fn suite_info_of_pair(pair: #(SuiteRun, types.SuiteInfo)) -> types.SuiteInfo {
  pair.1
}

fn suite_info_from_suite_run(suite_run: SuiteRun) -> types.SuiteInfo {
  let source = suite_source_from_tests(suite_run.tests)
  types.SuiteInfo(
    name: suite.name(suite_run.suite),
    tests: suite_run.tests,
    source: source,
  )
}

fn suite_source_from_tests(tests: List(types.TestInfo)) -> Option(String) {
  case tests {
    [] -> None
    [
      types.TestInfo(
        source: source,
        name: _name,
        groups: _groups,
        tags: _tags,
        kind: _kind,
      ),
      ..rest
    ] -> suite_source_from_tests_with_first(source, rest)
  }
}

fn suite_source_from_tests_with_first(
  first: Option(String),
  rest: List(types.TestInfo),
) -> Option(String) {
  case first {
    None -> None
    Some(value) ->
      case all_sources_match(value, rest) {
        True -> Some(value)
        False -> None
      }
  }
}

fn all_sources_match(value: String, rest: List(types.TestInfo)) -> Bool {
  case rest {
    [] -> True
    [
      types.TestInfo(
        source: source,
        name: _name,
        groups: _groups,
        tags: _tags,
        kind: _kind,
      ),
      ..next
    ] ->
      case source {
        Some(s) ->
          case s == value {
            True -> all_sources_match(value, next)
            False -> False
          }
        None -> False
      }
  }
}

/// A suite-level hook with the input that it gets, so that the setup process
/// process of its scope can run it.
type SuiteHookCall(input) {
  SuiteHookCall(hook: fn(input) -> Result(Nil, String), input: input)
}

fn call_suite_hook(call: SuiteHookCall(input)) -> Result(Nil, String) {
  call.hook(call.input)
}

/// The setup process of a suite-level scope: all suites, or one suite.
type SuiteSetupProcess(input) =
  SetupProcess(SuiteHookCall(input), Result(Nil, String))

/// The set-up hooks of a suite-level scope. `scope` is `[]` for the whole
/// run and `[suite name]` for one suite.
type SuiteSetUp(input) {
  SuiteSetUp(
    hooks: List(fn(input) -> Result(Nil, String)),
    input: input,
    scope: List(String),
    timeout_ms: Int,
  )
}

/// The tear-down hooks of a suite-level scope, the kind of hook that they
/// are in a `TeardownFailure`, and the set-up hook of the scope for a
/// `SetupStopped` failure.
type SuiteTearDown(input) {
  SuiteTearDown(
    hooks: List(fn(input) -> Result(Nil, String)),
    input: input,
    scope: List(String),
    timeout_ms: Int,
    hook_kind: TeardownHook,
    set_up: SetUpHook,
  )
}

/// The setup process of a suite-level scope whose set-up hooks returned.
type SuiteScopeSetupProcess(input) {
  /// The setup process was alive at the last check.
  SuiteSetupProcessAlive(setup_process: SuiteSetupProcess(input))
  /// The setup process stopped with `reason`. The suites of the scope that have
  /// not started do not run, and its tear-down hooks run in a new setup process.
  /// `not_run` is the full name of each test that it did not run, in the
  /// order of the run.
  SuiteSetupProcessGone(reason: String, not_run: List(List(String)))
}

fn alive_suite_setup_process(
  setup_process: Option(SuiteSetupProcess(input)),
) -> Option(SuiteScopeSetupProcess(input)) {
  case setup_process {
    Some(setup_process) ->
      Some(SuiteSetupProcessAlive(setup_process: setup_process))
    None -> None
  }
}

/// Look again at a setup process that was alive. The check takes the down
/// message of a stopped setup process, so its reason is kept in `SuiteSetupProcessGone`.
fn refresh_suite_setup_process(
  setup_process: Option(SuiteScopeSetupProcess(input)),
) -> Option(SuiteScopeSetupProcess(input)) {
  case setup_process {
    Some(SuiteSetupProcessAlive(setup_process: alive)) ->
      Some(checked_suite_setup_process(sandbox.check_setup_process(alive)))
    _ -> setup_process
  }
}

fn checked_suite_setup_process(
  checked: Result(SuiteSetupProcess(input), String),
) -> SuiteScopeSetupProcess(input) {
  case checked {
    Ok(alive) -> SuiteSetupProcessAlive(setup_process: alive)
    Error(reason) -> SuiteSetupProcessGone(reason: reason, not_run: [])
  }
}

/// The result of the suite-level set-up hooks of a scope, by cause.
type SuiteSetUpResult(input) {
  /// Every hook returned `Ok`, or the setup process exited. `setup_process` is
  /// `SuiteSetupProcessGone` when the setup process exited: the set-up stopped, so the
  /// tests of the scope are not run, and its tear-down hooks run in a new
  /// setup process. `setup_process` is `None` when the scope has no set-up hook.
  SuiteSetUpRan(setup_process: Option(SuiteScopeSetupProcess(input)))
  /// A hook returned `Error`, crashed inside the hook call, or timed out.
  /// `message` names the scope for a crash or a timeout. `setup_process` is the
  /// setup process when it is still alive.
  SuiteSetUpFailed(
    setup_process: Option(SuiteSetupProcess(input)),
    message: String,
  )
}

/// Run suite-level set-up hooks in order, in the setup process of their
/// scope, and stop at the first failure or when the setup process exits. The
/// first hook starts the setup process, so a resource that a hook starts lives
/// until the setup process stops after the tear-down hooks. Each hook gets the
/// timeout of the scope.
///
/// A hook that returns `Error`, crashes or times out is a failure of the
/// hook. A setup process that exits, while a hook runs or between two
/// hooks, stops the set-up.
fn run_suite_level_hooks(
  set_up: SuiteSetUp(input),
  setup_process: Option(SuiteSetupProcess(input)),
) -> SuiteSetUpResult(input) {
  case set_up.hooks {
    [] -> SuiteSetUpRan(setup_process: alive_suite_setup_process(setup_process))
    [hook, ..rest] ->
      suite_set_up_result(
        SuiteSetUp(..set_up, hooks: rest),
        sandbox.run_in_setup_process(
          setup_process,
          set_up.timeout_ms,
          call_suite_hook,
          SuiteHookCall(hook: hook, input: set_up.input),
        ),
      )
  }
}

fn suite_set_up_result(
  rest: SuiteSetUp(input),
  setup_process_result: SetupProcessResult(
    SuiteHookCall(input),
    Result(Nil, String),
  ),
) -> SuiteSetUpResult(input) {
  case setup_process_result {
    SetupProcessReturned(setup_process: setup_process, value: Ok(Nil)) ->
      run_suite_level_hooks(rest, Some(setup_process))
    SetupProcessReturned(setup_process: setup_process, value: Error(message)) ->
      SuiteSetUpFailed(setup_process: Some(setup_process), message: message)
    SetupProcessCaught(setup_process: setup_process, reason: reason) ->
      SuiteSetUpFailed(
        setup_process: Some(setup_process),
        message: suite_hook_crash_message(rest.scope, reason),
      )
    SetupProcessTimedOut ->
      SuiteSetUpFailed(
        setup_process: None,
        message: suite_hook_timeout_message(rest.scope),
      )
    SetupProcessExited(reason: reason) | SetupProcessLost(reason: reason) ->
      SuiteSetUpRan(
        setup_process: Some(SuiteSetupProcessGone(reason: reason, not_run: [])),
      )
  }
}

/// End a suite-level scope: report a setup process that stopped while the suites
/// ran, run every tear-down hook (in the setup process while it is alive, else in
/// a new setup process), then stop the setup process. Gives the failures in the order that
/// they happened.
fn finish_suite_scope(
  tear_down: SuiteTearDown(input),
  setup_process: Option(SuiteScopeSetupProcess(input)),
) -> List(TeardownFailure) {
  case setup_process, tear_down.hooks {
    None, _ -> run_suite_teardown(tear_down, None, [])
    Some(SuiteSetupProcessGone(reason: reason, not_run: not_run)), _ ->
      run_suite_teardown(tear_down, None, [
        suite_setup_stopped(tear_down, reason, not_run),
      ])
    Some(SuiteSetupProcessAlive(setup_process: alive)), [] ->
      stop_checked_suite_setup_process(
        tear_down,
        sandbox.check_setup_process(alive),
      )
    Some(SuiteSetupProcessAlive(setup_process: alive)), _ ->
      run_suite_teardown(tear_down, Some(alive), [])
  }
}

/// Run the tear-down hooks, then stop the last setup process.
fn run_suite_teardown(
  tear_down: SuiteTearDown(input),
  setup_process: Option(SuiteSetupProcess(input)),
  failures_rev: List(TeardownFailure),
) -> List(TeardownFailure) {
  let #(last_setup_process, next_failures_rev) =
    run_suite_teardown_hooks(
      tear_down,
      tear_down.hooks,
      setup_process,
      failures_rev,
    )
  let _stopped = option.map(last_setup_process, sandbox.stop_setup_process)
  list.reverse(next_failures_rev)
}

/// Stop the setup process of a scope with no tear-down hook, or report that it
/// stopped already.
fn stop_checked_suite_setup_process(
  tear_down: SuiteTearDown(input),
  checked: Result(SuiteSetupProcess(input), String),
) -> List(TeardownFailure) {
  case checked {
    Ok(setup_process) -> {
      sandbox.stop_setup_process(setup_process)
      []
    }
    Error(reason) -> [suite_setup_stopped(tear_down, reason, [])]
  }
}

fn suite_setup_stopped(
  tear_down: SuiteTearDown(input),
  reason: String,
  not_run: List(List(String)),
) -> TeardownFailure {
  SetupStopped(
    set_up: tear_down.set_up,
    groups: tear_down.scope,
    reason: reason,
    not_run: not_run,
  )
}

/// Run every suite-level tear-down hook, also after one fails, and give
/// the failures newest first, in front of `failures_rev`. After a timeout
/// or an exit of the setup process, the next hook runs in a new setup process. A setup process
/// that stopped before a hook started means that the set-up stopped: the
/// hook runs again in a new setup process, so it never stays not run.
fn run_suite_teardown_hooks(
  tear_down: SuiteTearDown(input),
  hooks: List(fn(input) -> Result(Nil, String)),
  setup_process: Option(SuiteSetupProcess(input)),
  failures_rev: List(TeardownFailure),
) -> #(Option(SuiteSetupProcess(input)), List(TeardownFailure)) {
  case hooks {
    [] -> #(setup_process, failures_rev)
    [hook, ..rest] ->
      suite_tear_down_result(
        tear_down,
        hook,
        rest,
        sandbox.run_in_setup_process(
          setup_process,
          tear_down.timeout_ms,
          call_suite_hook,
          SuiteHookCall(hook: hook, input: tear_down.input),
        ),
        failures_rev,
      )
  }
}

fn suite_tear_down_result(
  tear_down: SuiteTearDown(input),
  hook: fn(input) -> Result(Nil, String),
  rest: List(fn(input) -> Result(Nil, String)),
  setup_process_result: SetupProcessResult(
    SuiteHookCall(input),
    Result(Nil, String),
  ),
  failures_rev: List(TeardownFailure),
) -> #(Option(SuiteSetupProcess(input)), List(TeardownFailure)) {
  case setup_process_result {
    SetupProcessReturned(setup_process: setup_process, value: Ok(Nil)) ->
      run_suite_teardown_hooks(
        tear_down,
        rest,
        Some(setup_process),
        failures_rev,
      )
    SetupProcessReturned(setup_process: setup_process, value: Error(message)) ->
      run_suite_teardown_hooks(
        tear_down,
        rest,
        Some(setup_process),
        add_teardown_failure(tear_down, message, failures_rev),
      )
    SetupProcessCaught(setup_process: setup_process, reason: reason) ->
      run_suite_teardown_hooks(
        tear_down,
        rest,
        Some(setup_process),
        add_teardown_failure(
          tear_down,
          suite_hook_crash_message(tear_down.scope, reason),
          failures_rev,
        ),
      )
    SetupProcessTimedOut ->
      run_suite_teardown_hooks(
        tear_down,
        rest,
        None,
        add_teardown_failure(
          tear_down,
          suite_hook_timeout_message(tear_down.scope),
          failures_rev,
        ),
      )
    SetupProcessExited(reason: reason) ->
      run_suite_teardown_hooks(
        tear_down,
        rest,
        None,
        add_teardown_failure(
          tear_down,
          suite_hook_crash_message(tear_down.scope, reason),
          failures_rev,
        ),
      )
    SetupProcessLost(reason: reason) ->
      run_suite_teardown_hooks(tear_down, [hook, ..rest], None, [
        suite_setup_stopped(tear_down, reason, []),
        ..failures_rev
      ])
  }
}

/// Put a failure of a tear-down hook in front of `failures_rev`.
fn add_teardown_failure(
  tear_down: SuiteTearDown(input),
  message: String,
  failures_rev: List(TeardownFailure),
) -> List(TeardownFailure) {
  [
    TeardownFailure(
      hook: tear_down.hook_kind,
      groups: tear_down.scope,
      message: message,
    ),
    ..failures_rev
  ]
}

/// `hook crashed: <reason>` for a hook of the whole run, and
/// `hook crashed in <suite>: <reason>` for a hook of one suite.
fn suite_hook_crash_message(scope: List(String), reason: String) -> String {
  suite_scope_message("hook crashed", scope) <> ": " <> reason
}

/// `hook timed out` for a hook of the whole run, and
/// `hook timed out in <suite>` for a hook of one suite.
fn suite_hook_timeout_message(scope: List(String)) -> String {
  suite_scope_message("hook timed out", scope)
}

/// The text, then ` in <suite>` for a scope of one suite.
fn suite_scope_message(text: String, scope: List(String)) -> String {
  case scope {
    [] -> text
    _ -> text <> " in " <> string.join(scope, " > ")
  }
}

fn run_suites_with_hooks(
  suite_runs: List(#(SuiteRun, types.SuiteInfo)),
  default_config: parallel.ParallelConfig,
  progress_reporter: Option(progress.ProgressReporter),
  output: Output,
  total: Int,
  completed: Int,
  before_each_suite_hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  after_each_suite_hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  runner_before_each_test: List(fn(types.TestInfo) -> Result(Nil, String)),
  runner_after_each_test: List(fn(types.TestInfo) -> Result(Nil, String)),
  keep: Option(fn(TestInfo) -> Bool),
  collected: Collected,
  all_suites_setup_process: Option(
    SuiteScopeSetupProcess(List(types.SuiteInfo)),
  ),
) -> #(Collected, Int, Option(SuiteScopeSetupProcess(List(types.SuiteInfo)))) {
  let checked_setup_process =
    refresh_suite_setup_process(all_suites_setup_process)
  case suite_runs {
    [] -> #(collected, completed, checked_setup_process)
    [
      #(SuiteRun(suite: suite, config_override: override, ..), suite_info),
      ..rest
    ] -> {
      let suite_run =
        SuiteTests(
          suite: suite,
          config: suite_run_config(default_config, override),
          info: suite_info,
          progress_reporter: progress_reporter,
          output: output,
          total: total,
          completed: completed,
          runner_before_each_test: runner_before_each_test,
          runner_after_each_test: runner_after_each_test,
          keep: keep,
        )
      let #(suite_collected, completed_after_suite, setup_process_after_suite) =
        run_suite_in_run(
          suite_run,
          before_each_suite_hooks,
          after_each_suite_hooks,
          checked_setup_process,
        )
      run_suites_with_hooks(
        rest,
        default_config,
        progress_reporter,
        output,
        total,
        completed_after_suite,
        before_each_suite_hooks,
        after_each_suite_hooks,
        runner_before_each_test,
        runner_after_each_test,
        keep,
        Collected(
          tests: list.append(collected.tests, suite_collected.tests),
          teardown_failures: list.append(
            collected.teardown_failures,
            suite_collected.teardown_failures,
          ),
        ),
        setup_process_after_suite,
      )
    }
  }
}

/// What stays the same while the tests of one suite run.
type SuiteTests {
  SuiteTests(
    suite: TestSuite,
    config: parallel.ParallelConfig,
    info: types.SuiteInfo,
    progress_reporter: Option(progress.ProgressReporter),
    output: Output,
    total: Int,
    completed: Int,
    runner_before_each_test: List(fn(types.TestInfo) -> Result(Nil, String)),
    runner_after_each_test: List(fn(types.TestInfo) -> Result(Nil, String)),
    keep: Option(fn(TestInfo) -> Bool),
  )
}

/// Run one suite in the scope of the whole run. After the setup process of the
/// run stopped, no suite-level hook runs.
fn run_suite_in_run(
  suite_run: SuiteTests,
  before_each_suite_hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  after_each_suite_hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  all_suites_setup_process: Option(
    SuiteScopeSetupProcess(List(types.SuiteInfo)),
  ),
) -> #(Collected, Int, Option(SuiteScopeSetupProcess(List(types.SuiteInfo)))) {
  case all_suites_setup_process {
    Some(SuiteSetupProcessGone(..)) ->
      run_suite_after_run_setup_stopped(suite_run, all_suites_setup_process)
    _ ->
      run_one_suite(
        suite_run,
        before_each_suite_hooks,
        after_each_suite_hooks,
        all_suites_setup_process,
      )
  }
}

/// Run a suite after the setup process of the whole run stopped. No suite-level
/// hook runs, and the executor gives `SetupFailed` to each test.
fn run_suite_after_run_setup_stopped(
  suite_run: SuiteTests,
  all_suites_setup_process: Option(
    SuiteScopeSetupProcess(List(types.SuiteInfo)),
  ),
) -> #(Collected, Int, Option(SuiteScopeSetupProcess(List(types.SuiteInfo)))) {
  let result =
    run_suite_tests(
      suite_run,
      outer_setup(BeforeAllSuitesHook, [], all_suites_setup_process),
    )
  #(
    Collected(
      tests: result.results,
      teardown_failures: result.teardown_failures,
    ),
    result.completed,
    stopped_suite_setup_process(
      all_suites_setup_process,
      BeforeAllSuitesHook,
      result.outer_setups,
    ),
  )
}

/// Run `before_each_suite`, then the tests of one suite, then
/// `after_each_suite`. A failed `before_each_suite` hook gives
/// `SetupFailed` to every test of the suite. The executor checks the setup process
/// of the whole run and the setup process of the suite before each test starts.
fn run_one_suite(
  suite_run: SuiteTests,
  before_each_suite_hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  after_each_suite_hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  all_suites_setup_process: Option(
    SuiteScopeSetupProcess(List(types.SuiteInfo)),
  ),
) -> #(Collected, Int, Option(SuiteScopeSetupProcess(List(types.SuiteInfo)))) {
  let suite_scope = [suite_run.info.name]
  let before_result =
    run_suite_level_hooks(
      SuiteSetUp(
        hooks: before_each_suite_hooks,
        input: suite_run.info,
        scope: suite_scope,
        timeout_ms: suite_run.config.default_timeout_ms,
      ),
      None,
    )
  let #(
    tests_collected,
    completed_after_tests,
    all_setup_process,
    suite_setup_process,
  ) = case before_result {
    SuiteSetUpFailed(setup_process: setup_process, message: message) -> {
      let setup_failures =
        setup_failed_results_from_tests(
          suite_run.info.tests,
          "before_each_suite",
          message,
        )
      #(
        Collected(tests: setup_failures, teardown_failures: []),
        emit_test_finished_progress_results(
          suite_run.progress_reporter,
          suite_run.output,
          suite_run.completed,
          suite_run.total,
          setup_failures,
        ),
        all_suites_setup_process,
        alive_suite_setup_process(setup_process),
      )
    }
    SuiteSetUpRan(setup_process: suite_setup_process) -> {
      let result =
        run_suite_tests(
          suite_run,
          list.append(
            outer_setup(BeforeAllSuitesHook, [], all_suites_setup_process),
            outer_setup(BeforeEachSuiteHook, suite_scope, suite_setup_process),
          ),
        )
      #(
        Collected(
          tests: result.results,
          teardown_failures: result.teardown_failures,
        ),
        result.completed,
        stopped_suite_setup_process(
          all_suites_setup_process,
          BeforeAllSuitesHook,
          result.outer_setups,
        ),
        stopped_suite_setup_process(
          suite_setup_process,
          BeforeEachSuiteHook,
          result.outer_setups,
        ),
      )
    }
  }
  let after_each_failures =
    finish_suite_scope(
      SuiteTearDown(
        hooks: after_each_suite_hooks,
        input: suite_run.info,
        scope: suite_scope,
        timeout_ms: suite_run.config.default_timeout_ms,
        hook_kind: AfterEachSuiteHook,
        set_up: BeforeEachSuiteHook,
      ),
      suite_setup_process,
    )
  #(
    Collected(
      tests: tests_collected.tests,
      teardown_failures: list.append(
        tests_collected.teardown_failures,
        after_each_failures,
      ),
    ),
    completed_after_tests,
    all_setup_process,
  )
}

/// Run the tests of one suite in the executor, inside `outer_setups`.
fn run_suite_tests(
  suite_run: SuiteTests,
  outer_setups: List(parallel.OuterSetup),
) -> parallel.RunRootParallelWithReporterResult {
  suite.run(
    suite_run.suite,
    suite.RunInput(
      config: suite_run.config,
      keep: suite_run.keep,
      progress_reporter: suite_run.progress_reporter,
      write: output_out(suite_run.output),
      total: suite_run.total,
      completed: suite_run.completed,
      before_each_test: suite_run.runner_before_each_test,
      after_each_test: suite_run.runner_after_each_test,
      outer_setups: outer_setups,
    ),
  )
}

/// The suite-level set-up of `setup_process` as the executor sees it: no set-up
/// when it has no setup process.
fn outer_setup(
  set_up: SetUpHook,
  scope: List(String),
  setup_process: Option(SuiteScopeSetupProcess(input)),
) -> List(parallel.OuterSetup) {
  case setup_process {
    None -> []
    Some(SuiteSetupProcessAlive(setup_process: alive)) -> [
      parallel.SetupRunning(
        set_up: set_up,
        groups: scope,
        check_setup_process: fn() { check_suite_setup_process(alive) },
      ),
    ]
    Some(SuiteSetupProcessGone(reason: reason, not_run: not_run)) -> [
      parallel.SetupStopped(
        set_up: set_up,
        groups: scope,
        reason: reason,
        not_run: not_run,
      ),
    ]
  }
}

fn check_suite_setup_process(
  setup_process: SuiteSetupProcess(input),
) -> Result(Nil, String) {
  sandbox.check_setup_process(setup_process)
  |> result.replace(Nil)
}

/// The setup process after the executor ran: gone when the executor saw the
/// set-up `set_up` stopped. The check of the executor took the down message of
/// the setup process, so its reason comes from `outer_setups`, with the tests that
/// the executor did not run because of it.
fn stopped_suite_setup_process(
  setup_process: Option(SuiteScopeSetupProcess(input)),
  set_up: SetUpHook,
  outer_setups: List(parallel.OuterSetup),
) -> Option(SuiteScopeSetupProcess(input)) {
  case setup_process, find_stopped_setup_process(outer_setups, set_up) {
    Some(_), Ok(gone) -> Some(gone)
    _, _ -> setup_process
  }
}

/// The first of `outer_setups` that says the set-up `set_up` stopped, as
/// a gone setup process.
fn find_stopped_setup_process(
  outer_setups: List(parallel.OuterSetup),
  set_up: SetUpHook,
) -> Result(SuiteScopeSetupProcess(input), Nil) {
  case outer_setups {
    [] -> Error(Nil)
    [outer_setup, ..rest] ->
      stopped_setup_process_or_next(
        stopped_setup_process(outer_setup, set_up),
        rest,
        set_up,
      )
  }
}

fn stopped_setup_process_or_next(
  found: Result(SuiteScopeSetupProcess(input), Nil),
  rest: List(parallel.OuterSetup),
  set_up: SetUpHook,
) -> Result(SuiteScopeSetupProcess(input), Nil) {
  case found {
    Ok(gone) -> Ok(gone)
    Error(Nil) -> find_stopped_setup_process(rest, set_up)
  }
}

fn stopped_setup_process(
  outer_setup: parallel.OuterSetup,
  set_up: SetUpHook,
) -> Result(SuiteScopeSetupProcess(input), Nil) {
  case outer_setup {
    parallel.SetupStopped(
      set_up: stopped,
      groups: _,
      reason: reason,
      not_run: not_run,
    )
      if stopped == set_up
    -> Ok(SuiteSetupProcessGone(reason: reason, not_run: not_run))
    _ -> Error(Nil)
  }
}

fn setup_failed_results_from_suites(
  suites: List(types.SuiteInfo),
  operator: String,
  message: String,
) -> List(TestResult) {
  setup_failed_results_from_suites_rev(suites, operator, message, [])
  |> list.reverse()
}

fn setup_failed_results_from_suites_rev(
  suites: List(types.SuiteInfo),
  operator: String,
  message: String,
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case suites {
    [] -> acc_rev
    [suite, ..rest] ->
      setup_failed_results_from_suites_rev(
        rest,
        operator,
        message,
        setup_failed_results_from_tests_rev(
          suite.tests,
          operator,
          message,
          acc_rev,
        ),
      )
  }
}

fn setup_failed_results_from_tests(
  tests: List(types.TestInfo),
  operator: String,
  message: String,
) -> List(TestResult) {
  setup_failed_results_from_tests_rev(tests, operator, message, [])
  |> list.reverse()
}

fn setup_failed_results_from_tests_rev(
  tests: List(types.TestInfo),
  operator: String,
  message: String,
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case tests {
    [] -> acc_rev
    [test_info, ..rest] ->
      setup_failed_results_from_tests_rev(rest, operator, message, [
        setup_failed_result_for_test_info(test_info, operator, message),
        ..acc_rev
      ])
  }
}

fn setup_failed_result_for_test_info(
  info: types.TestInfo,
  operator: String,
  message: String,
) -> TestResult {
  let types.TestInfo(
    name: name,
    groups: groups,
    tags: tags,
    kind: kind,
    source: _source,
  ) = info
  types.TestResult(
    name: name,
    groups: groups,
    status: SetupFailed,
    duration_ms: 0,
    tags: tags,
    failures: [hook_failure(operator, message)],
    kind: kind,
  )
}

fn hook_failure(operator: String, message: String) -> AssertionFailure {
  types.AssertionFailure(operator: operator, message: message, payload: None)
}

fn emit_test_finished_progress(
  progress_reporter: Option(progress.ProgressReporter),
  output: Output,
  completed: Int,
  total: Int,
  result: TestResult,
) -> Int {
  let next_completed = completed + 1
  case progress_reporter {
    None -> next_completed
    Some(reporter) -> {
      write_progress_event(
        reporter,
        progress.TestFinishedProgress(
          completed: next_completed,
          total: total,
          result: result,
        ),
        output,
      )
      next_completed
    }
  }
}

fn emit_test_finished_progress_results(
  progress_reporter: Option(progress.ProgressReporter),
  output: Output,
  completed: Int,
  total: Int,
  results: List(TestResult),
) -> Int {
  case results {
    [] -> completed
    [result, ..rest] ->
      emit_test_finished_progress_results(
        progress_reporter,
        output,
        emit_test_finished_progress(
          progress_reporter,
          output,
          completed,
          total,
          result,
        ),
        total,
        rest,
      )
  }
}

fn default_output() -> Output {
  Output(out: io.print, error: io.print_error)
}

/// The output of a silent run: normal output is dropped, and errors still
/// go to the standard error stream.
fn silent_output() -> Output {
  Output(out: discard_output, error: io.print_error)
}

fn discard_output(_text: String) -> Nil {
  Nil
}

fn maybe_exit_on_failure(
  should_exit: Bool,
  report: RunReport,
  coverage_succeeded: Bool,
) -> Nil {
  let should_stop =
    should_exit && { types.failed(report) || !coverage_succeeded }
  case should_stop {
    // Gleam 1.13 and older halt the BEAM with status 0 at once when `main`
    // returns. `end_program` does not return, so `main` does not return, no
    // line after `runner.run` runs, and the status stays 1.
    True -> end_program(1)
    False -> Nil
  }
}

/// The suite runs that keep at least one test, each with only the tests
/// that the filter keeps. A suite with no test to run is left out, with or
/// without a filter, so its suite hooks do not run.
fn apply_test_filter(
  suite_runs: List(SuiteRun),
  predicate: Option(fn(TestInfo) -> Bool),
) -> List(SuiteRun) {
  filter_suite_runs(suite_runs, option.unwrap(predicate, keep_every_test), [])
}

fn keep_every_test(_info: TestInfo) -> Bool {
  True
}

fn filter_suite_runs(
  suite_runs: List(SuiteRun),
  keep: fn(TestInfo) -> Bool,
  kept_rev: List(SuiteRun),
) -> List(SuiteRun) {
  case suite_runs {
    [] -> list.reverse(kept_rev)
    [suite_run, ..rest] ->
      filter_suite_runs(
        rest,
        keep,
        add_kept_suite_run(
          suite_run,
          list.filter(suite_run.tests, keep),
          kept_rev,
        ),
      )
  }
}

/// Add the suite run with the tests `kept`, when there is at least one.
fn add_kept_suite_run(
  suite_run: SuiteRun,
  kept: List(TestInfo),
  kept_rev: List(SuiteRun),
) -> List(SuiteRun) {
  case kept {
    [] -> kept_rev
    _ -> [SuiteRun(..suite_run, tests: kept), ..kept_rev]
  }
}

/// The hooks around all suites: none when no suite has a test to run.
fn all_suites_hooks(
  suite_runs: List(SuiteRun),
  hooks: List(hook),
) -> List(hook) {
  case suite_runs {
    [] -> []
    _ -> hooks
  }
}

fn suite_run_config(
  default_config: parallel.ParallelConfig,
  override: Option(parallel.ParallelConfig),
) -> parallel.ParallelConfig {
  case override {
    None -> default_config
    Some(config) -> config
  }
}

type CoverageState {
  CoverageOff
  CoverageRunning(session: CoverageSession, config: CoverageConfig)
  CoverageStartFailed(error: coverage.CoverageError)
}

/// How the builder asks for coverage.
type CoverageRequest {
  NoCoverage
  AlwaysCoverage(config: CoverageConfig)
  CoverageFromEnvironment(config: CoverageConfig)
}

/// The environment variable read by `coverage_from_environment`.
const coverage_environment_variable = "DREAM_TEST_COVERAGE"

@external(erlang, "dream_test_coverage_ffi", "environment_variable")
fn environment_variable(name: String) -> Result(String, Nil)

fn start_coverage(request: CoverageRequest) -> CoverageState {
  case request {
    NoCoverage -> CoverageOff
    AlwaysCoverage(config) -> start_coverage_with(config)
    CoverageFromEnvironment(config) ->
      start_coverage_from_environment(
        environment_variable(coverage_environment_variable),
        config,
      )
  }
}

fn start_coverage_with(config: CoverageConfig) -> CoverageState {
  coverage_state_from_start(coverage.start(config), config)
}

fn start_coverage_from_environment(
  value: Result(String, Nil),
  config: CoverageConfig,
) -> CoverageState {
  case value {
    Error(Nil) -> CoverageOff
    Ok("1") | Ok("true") -> start_coverage_with(config)
    Ok("0") | Ok("false") -> CoverageOff
    Ok(other) ->
      CoverageStartFailed(coverage.InvalidEnvironmentValue(
        name: coverage_environment_variable,
        value: other,
      ))
  }
}

fn coverage_state_from_start(
  result: Result(CoverageSession, coverage.CoverageError),
  config: CoverageConfig,
) -> CoverageState {
  case result {
    Ok(session) -> CoverageRunning(session, config)
    Error(error) -> CoverageStartFailed(error)
  }
}

/// Print the coverage table to the reporter output, or the coverage failure
/// block to the error output (once, after the results reporters).
/// Returns `False` on error.
fn finish_coverage(
  state: CoverageState,
  output: Output,
  outcome: coverage_reporter.RunOutcome,
) -> Bool {
  case state {
    CoverageOff -> True
    CoverageRunning(session, config) ->
      write_coverage_result(coverage.finish(session), config, output, outcome)
    CoverageStartFailed(error) -> write_coverage_error(error, output, outcome)
  }
}

fn write_coverage_result(
  result: Result(CoverageReport, coverage.CoverageError),
  config: CoverageConfig,
  output: Output,
  outcome: coverage_reporter.RunOutcome,
) -> Bool {
  case result {
    Ok(report) -> {
      output_out(output)(coverage_reporter.render(
        report: report,
        config: config,
      ))
      let total_met =
        write_minimum_result(
          coverage.check_minimum(config: config, report: report),
          output,
          outcome,
        )
      let each_file_met =
        write_minimum_result(
          coverage.check_minimum_per_file(config: config, report: report),
          output,
          outcome,
        )
      total_met && each_file_met
    }
    Error(error) -> write_coverage_error(error, output, outcome)
  }
}

fn write_minimum_result(
  result: Result(Nil, coverage.CoverageError),
  output: Output,
  outcome: coverage_reporter.RunOutcome,
) -> Bool {
  case result {
    Ok(Nil) -> True
    Error(error) -> write_coverage_error(error, output, outcome)
  }
}

fn write_coverage_error(
  error: coverage.CoverageError,
  output: Output,
  outcome: coverage_reporter.RunOutcome,
) -> Bool {
  let Output(out: _out, error: write_error) = output
  write_error(coverage_reporter.render_failure(error: error, outcome: outcome))
  False
}

fn run_outcome(
  report: RunReport,
  exit_on_failure: Bool,
) -> coverage_reporter.RunOutcome {
  let tests = types.report_tests(report)
  let counts = summary.count(report)
  coverage_reporter.RunOutcome(
    passed: list.count(tests, is_passed),
    failed: list.count(tests, is_failure),
    teardown_failed: counts.teardown_failed,
    setup_stopped: counts.setup_stopped,
    reporters_crashed: list.length(types.report_reporter_crashes(report)),
    exit_on_failure: exit_on_failure,
  )
}

fn is_passed(result: TestResult) -> Bool {
  result.status == Passed
}

fn is_failure(result: TestResult) -> Bool {
  types.is_failure(result.status)
}

fn write_progress_event(
  reporter: progress.ProgressReporter,
  event: progress.ProgressEvent,
  output: Output,
) -> Nil {
  output_out(output)(progress.line(reporter, event))
}

/// Write the report of each results reporter in list order, and return
/// the reporters that crashed. A crash does not stop the run: the runner
/// writes a named error to the error output and goes on with the next
/// reporter. A custom render function that does not return in
/// `timeout_ms` is stopped, and counts as a crash. Positions start at 1
/// and count every reporter in the list.
fn write_results_reporters(
  reporters: List(reporter_types.ResultsReporter),
  report: RunReport,
  output: Output,
  timeout_ms: Int,
) -> List(types.ReporterCrash) {
  write_results_reporters_loop(reporters, report, output, timeout_ms, 1, [])
}

fn write_results_reporters_loop(
  reporters: List(reporter_types.ResultsReporter),
  report: RunReport,
  output: Output,
  timeout_ms: Int,
  position: Int,
  crashes_in_reverse: List(types.ReporterCrash),
) -> List(types.ReporterCrash) {
  case reporters {
    [] -> list.reverse(crashes_in_reverse)
    [reporter, ..rest] ->
      write_results_reporters_loop(
        rest,
        report,
        output,
        timeout_ms,
        position + 1,
        list.append(
          write_results_reporter(reporter, report, output, timeout_ms, position),
          crashes_in_reverse,
        ),
      )
  }
}

/// Write the report of one results reporter, and return its crash when
/// its render function crashed or did not return in `timeout_ms`, else
/// `[]`.
fn write_results_reporter(
  reporter: reporter_types.ResultsReporter,
  report: RunReport,
  output: Output,
  timeout_ms: Int,
  position: Int,
) -> List(types.ReporterCrash) {
  let Output(out: write_out, error: write_error) = output
  case reporter {
    reporter_types.Bdd(config) -> {
      write_out(bdd.render(config, report))
      []
    }
    reporter_types.Json(config) -> {
      write_out(json.render(config, report))
      []
    }
    reporter_types.Custom(render) ->
      write_custom_report(
        sandbox.run_isolated(
          SandboxConfig(timeout_ms: timeout_ms, show_crash_reports: False),
          render,
          report,
        ),
        write_out,
        write_error,
        timeout_ms,
        position,
      )
  }
}

fn write_custom_report(
  rendered: SandboxResult(String),
  write_out: fn(String) -> Nil,
  write_error: fn(String) -> Nil,
  timeout_ms: Int,
  position: Int,
) -> List(types.ReporterCrash) {
  case rendered {
    SandboxCompleted(text) -> {
      write_out(text)
      []
    }
    SandboxCrashed(reason: crash) -> {
      write_error(custom_reporter_crash(position, crash))
      [types.ReporterCrash(position: position, reason: crash)]
    }
    SandboxTimedOut -> {
      write_error(custom_reporter_timeout(position, timeout_ms))
      [
        types.ReporterCrash(
          position: position,
          reason: "did not return in " <> int.to_string(timeout_ms) <> " ms",
        ),
      ]
    }
  }
}

fn custom_reporter_timeout(position: Int, timeout_ms: Int) -> String {
  "\nResults reporter failed\n"
  <> "  The Custom results reporter at position "
  <> int.to_string(position)
  <> " in runner.results_reporters did not return in "
  <> int.to_string(timeout_ms)
  <> " ms.\n"
  <> "  Reason: the runner stops a render function that runs longer than runner.default_timeout_ms, so this reporter wrote no report.\n"
  <> "  Fix: make the render function return a String in time, or give runner.default_timeout_ms a larger value.\n"
  <> "\n"
}

/// The most characters of a crash reason that the error output shows.
const shown_crash_reason_length = 200

fn custom_reporter_crash(position: Int, crash: String) -> String {
  "\nResults reporter failed\n"
  <> "  The Custom results reporter at position "
  <> int.to_string(position)
  <> " in runner.results_reporters crashed: "
  <> shown_crash_reason(one_line(crash))
  <> "\n"
  <> "  Reason: its render function crashed, so this reporter wrote no report.\n"
  <> "  Fix: make the render function return a String for every RunReport.\n"
  <> "\n"
}

/// The lines of `text`, each without the spaces at its start, joined with
/// one space.
fn one_line(text: String) -> String {
  text
  |> string.split("\n")
  |> list.map(string.trim_start)
  |> string.join(" ")
}

/// `reason`, or its first `shown_crash_reason_length` characters and a
/// note that says where the full reason is.
fn shown_crash_reason(reason: String) -> String {
  case string.length(reason) > shown_crash_reason_length {
    True ->
      string.slice(reason, 0, shown_crash_reason_length)
      <> " ... (cut at "
      <> int.to_string(shown_crash_reason_length)
      <> " characters, and types.report_reporter_crashes has the full reason)"
    False -> reason
  }
}

fn output_out(output: Output) -> fn(String) -> Nil {
  let Output(out: out, error: _error) = output
  out
}

fn count_total_tests(suite_runs: List(SuiteRun)) -> Int {
  list.fold(suite_runs, 0, add_test_count)
}

fn add_test_count(count: Int, suite_run: SuiteRun) -> Int {
  count + list.length(suite_run.tests)
}

// ============================================================================
// Suite run list helpers (no anonymous fns)
// ============================================================================

fn suites_to_suite_runs_default(
  suites: List(TestSuite),
  acc_rev: List(SuiteRun),
) -> List(SuiteRun) {
  case suites {
    [] -> list.reverse(acc_rev)
    [suite, ..rest] ->
      suites_to_suite_runs_default(rest, [
        SuiteRun(suite: suite, config_override: None, tests: suite.tests(suite)),
        ..acc_rev
      ])
  }
}

fn suites_to_suite_runs_with_override(
  config: parallel.ParallelConfig,
  suites: List(TestSuite),
  acc_rev: List(SuiteRun),
) -> List(SuiteRun) {
  case suites {
    [] -> list.reverse(acc_rev)
    [suite, ..rest] ->
      suites_to_suite_runs_with_override(config, rest, [
        SuiteRun(
          suite: suite,
          config_override: Some(config),
          tests: suite.tests(suite),
        ),
        ..acc_rev
      ])
  }
}

fn append_suite_runs_default(
  existing: List(SuiteRun),
  suites: List(TestSuite),
) -> List(SuiteRun) {
  list.append(existing, suites_to_suite_runs_default(suites, []))
}

fn append_suite_runs_with_override(
  existing: List(SuiteRun),
  config: parallel.ParallelConfig,
  suites: List(TestSuite),
) -> List(SuiteRun) {
  list.append(existing, suites_to_suite_runs_with_override(config, suites, []))
}

/// Ask the BEAM to stop with `status`, then wait until the BEAM stops.
/// Never returns.
@external(erlang, "dream_test_runner_ffi", "end_program")
fn end_program(status: Int) -> Nil
