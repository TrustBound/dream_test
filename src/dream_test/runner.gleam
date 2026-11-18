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
  type Owner, type OwnerResult, OwnerCaught, OwnerExited, OwnerLost,
  OwnerReturned, OwnerTimedOut,
}
import dream_test/types.{
  type AssertionFailure, type Node, type RunReport, type SetUpHook,
  type TeardownFailure, type TeardownHook, type TestResult, type TestSuite,
  AfterAll, AfterAllSuitesHook, AfterEach, AfterEachSuiteHook, BeforeAll,
  BeforeAllSuitesHook, BeforeEach, BeforeEachSuiteHook, Group, Passed, Root,
  SetupFailed, SetupStopped, TeardownFailure, Test,
}
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
pub opaque type RunBuilder(ctx) {
  RunBuilder(
    suite_runs: List(SuiteRun(ctx)),
    config: parallel.ParallelConfig,
    test_filter: Option(fn(TestInfo) -> Bool),
    should_exit_on_failure: Bool,
    progress_reporter: Option(progress.ProgressReporter),
    results_reporters: List(reporter_types.ResultsReporter),
    output: Option(Output),
    coverage: CoverageRequest,
    runner_before_each_test: List(
      fn(types.TestInfo, ctx) -> Result(ctx, String),
    ),
    runner_after_each_test: List(fn(types.TestInfo, ctx) -> Result(Nil, String)),
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

type SuiteRun(ctx) {
  SuiteRun(
    suite: TestSuite(ctx),
    config_override: Option(parallel.ParallelConfig),
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
/// The type parameter `ctx` is the suite context type. For `dream_test/unit`
/// suites this is `Nil`. For `dream_test/unit_context` suites it is your custom
/// context type.
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
/// A `RunBuilder(ctx)` you can pipe through configuration helpers and finally
/// `runner.run()`.
pub fn new(suites suites: List(TestSuite(ctx))) -> RunBuilder(ctx) {
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
  builder builder: RunBuilder(ctx),
  suites suites: List(TestSuite(ctx)),
) -> RunBuilder(ctx) {
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
  builder builder: RunBuilder(ctx),
  config config: parallel.ParallelConfig,
  suites suites: List(TestSuite(ctx)),
) -> RunBuilder(ctx) {
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
/// The updated `RunBuilder(ctx)`.
pub fn max_concurrency(
  builder builder: RunBuilder(ctx),
  max max: Int,
) -> RunBuilder(ctx) {
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
/// sequential runs. Each hook gets the same timeout on its own.
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
/// The updated `RunBuilder(ctx)`.
pub fn default_timeout_ms(
  builder builder: RunBuilder(ctx),
  timeout_ms timeout_ms: Int,
) -> RunBuilder(ctx) {
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
/// The run fails when a test is `Failed`, `SetupFailed` or `TimedOut`, when
/// a tear-down hook fails (see `types.failed`), or when coverage fails.
///
/// Useful for CI pipelines.
///
/// `runner.run` asks the BEAM to stop with status 1 (`init:stop(1)`), the
/// same way that Gleam stops a `main` that crashes. The BEAM then shuts
/// down cleanly: the output is written, and applications stop. Code after
/// `runner.run` can still run until the shutdown stops it, and the exit
/// status stays 1 when `main` returns.
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
/// The updated `RunBuilder(ctx)`.
pub fn exit_on_failure(builder builder: RunBuilder(ctx)) -> RunBuilder(ctx) {
  RunBuilder(..builder, should_exit_on_failure: True)
}

/// Attach a progress reporter (live output during the run).
///
/// This reporter is driven by `TestFinished` events in completion order.
/// It is intended for a single in-place progress bar UI.
pub fn progress_reporter(
  builder builder: RunBuilder(ctx),
  reporter reporter: progress.ProgressReporter,
) -> RunBuilder(ctx) {
  RunBuilder(..builder, progress_reporter: Some(reporter))
}

/// Attach results reporters (printed at the end, in the order provided).
///
/// Each results reporter gets the run report once, after the run ends. Its
/// tests are in traversal order, so the output is the same under parallel
/// execution.
pub fn results_reporters(
  builder builder: RunBuilder(ctx),
  reporters reporters: List(reporter_types.ResultsReporter),
) -> RunBuilder(ctx) {
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
  builder builder: RunBuilder(ctx),
  output output: Output,
) -> RunBuilder(ctx) {
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
  builder builder: RunBuilder(ctx),
  config config: CoverageConfig,
) -> RunBuilder(ctx) {
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
  builder builder: RunBuilder(ctx),
  config config: CoverageConfig,
) -> RunBuilder(ctx) {
  RunBuilder(..builder, coverage: CoverageFromEnvironment(config))
}

/// Disable all reporter output (still returns results from `runner.run()`).
pub fn silent(builder builder: RunBuilder(ctx)) -> RunBuilder(ctx) {
  RunBuilder(..builder, output: Some(silent_output()))
}

/// Filter which tests are executed.
///
/// The predicate receives `TestInfo` (name, full name, effective tags, kind).
/// Tags include inherited group tags.
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
/// The updated `RunBuilder(ctx)`.
pub fn filter_tests(
  builder builder: RunBuilder(ctx),
  predicate predicate: fn(TestInfo) -> Bool,
) -> RunBuilder(ctx) {
  RunBuilder(..builder, test_filter: Some(predicate))
}

/// Register a runner-level hook that runs before each test.
///
/// The hook receives `types.TestInfo` and the current context value.
/// If it returns `Error("...")`, the test is marked `SetupFailed`
/// and the test body does not run.
///
/// ## Example
///
/// ```gleam
/// import dream_test/runner
/// import dream_test/types.{type TestInfo}
///
/// fn log_test(info: TestInfo, ctx: Nil) {
///   io.println("starting " <> string.join(types.full_name(info.groups, info.name), " > "))
///   Ok(ctx)
/// }
///
/// runner.new([suite])
/// |> runner.before_each_test(log_test)
/// ```
pub fn before_each_test(
  builder builder: RunBuilder(ctx),
  hook hook: fn(types.TestInfo, ctx) -> Result(ctx, String),
) -> RunBuilder(ctx) {
  RunBuilder(
    ..builder,
    runner_before_each_test: list.append(builder.runner_before_each_test, [hook]),
  )
}

/// Register a runner-level hook that runs after each test.
///
/// The hook receives `types.TestInfo` and the current context value. It runs
/// in the process of the test, after the body, with the default timeout. If
/// the body timed out or the test process stopped, it runs in a new process.
/// Every `after_each_test` hook
/// runs, also after one fails. If it returns `Error("...")` or crashes, the
/// status of the test does not change: the run report gets a
/// `types.TeardownFailure` with hook `AfterEachTestHook`, and the run fails.
pub fn after_each_test(
  builder builder: RunBuilder(ctx),
  hook hook: fn(types.TestInfo, ctx) -> Result(Nil, String),
) -> RunBuilder(ctx) {
  RunBuilder(
    ..builder,
    runner_after_each_test: list.append(builder.runner_after_each_test, [hook]),
  )
}

/// Register a runner-level hook that runs before each suite.
///
/// The hook receives `types.SuiteInfo` for the suite about to run. It runs
/// in the owner process of the suite, so a resource that it starts lives
/// until the `after_each_suite` hooks of the suite end. It gets the default
/// timeout of the suite.
/// If it returns `Error("...")`, times out or crashes, all tests in that suite are
/// marked `SetupFailed`, the suite does not run, and `after_each_suite`
/// still runs.
pub fn before_each_suite(
  builder builder: RunBuilder(ctx),
  hook hook: fn(types.SuiteInfo) -> Result(Nil, String),
) -> RunBuilder(ctx) {
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
/// in the owner process of the suite, with the default timeout of the
/// suite. Every `after_each_suite` hook runs, also after one fails. If it
/// returns `Error("...")`, times out or crashes, the
/// run report gets a `types.TeardownFailure` with hook `AfterEachSuiteHook`
/// and the suite name in `groups`, and the run fails.
pub fn after_each_suite(
  builder builder: RunBuilder(ctx),
  hook hook: fn(types.SuiteInfo) -> Result(Nil, String),
) -> RunBuilder(ctx) {
  RunBuilder(
    ..builder,
    runner_after_each_suite: list.append(builder.runner_after_each_suite, [hook]),
  )
}

/// Register a runner-level hook that runs before all suites.
///
/// The hook receives the full list of `SuiteInfo` after filtering. It runs
/// in the owner process of the run, so a resource that it starts (for
/// example a pool that links to the caller) lives until `after_all_suites`
/// stops it. It gets the default timeout.
/// If it returns `Error("...")`, times out or crashes, all selected tests are marked
/// `SetupFailed`, no suite runs, and `after_all_suites` still runs.
pub fn before_all_suites(
  builder builder: RunBuilder(ctx),
  hook hook: fn(List(types.SuiteInfo)) -> Result(Nil, String),
) -> RunBuilder(ctx) {
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
/// in the owner process of the run, with the default timeout. Every
/// `after_all_suites` hook runs, also after one fails. If it returns
/// `Error("...")`, times out or crashes, the
/// run report gets a `types.TeardownFailure` with hook `AfterAllSuitesHook`
/// and `groups: []`, and the run fails.
pub fn after_all_suites(
  builder builder: RunBuilder(ctx),
  hook hook: fn(List(types.SuiteInfo)) -> Result(Nil, String),
) -> RunBuilder(ctx) {
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
/// when `types.failed(report)` is `True`.
pub fn run(builder builder: RunBuilder(ctx)) -> RunReport {
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
        hooks: builder.runner_before_all_suites,
        input: suite_infos,
        scope: [],
        timeout_ms: all_suites_timeout_ms,
      ),
      None,
    )

  let #(collected, completed2, all_suites_owner_after_run) = case
    before_all_result
  {
    SuiteSetUpRan(owner: all_suites_owner) ->
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
        Collected(tests: [], teardown_failures: []),
        all_suites_owner,
      )
    SuiteSetUpFailed(owner: all_suites_owner, message: message) -> {
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
        alive_suite_owner(all_suites_owner),
      )
    }
  }

  let after_all_failures =
    finish_suite_scope(
      SuiteTearDown(
        hooks: builder.runner_after_all_suites,
        input: suite_infos,
        scope: [],
        timeout_ms: all_suites_timeout_ms,
        hook_kind: AfterAllSuitesHook,
        set_up: BeforeAllSuitesHook,
      ),
      all_suites_owner_after_run,
    )

  let report =
    types.run_report(
      tests: collected.tests,
      teardown_failures: list.append(
        collected.teardown_failures,
        after_all_failures,
      ),
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

  write_results_reporters(builder.results_reporters, report, output)

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
  suite_runs: List(SuiteRun(ctx)),
  acc_rev: List(#(SuiteRun(ctx), types.SuiteInfo)),
) -> List(#(SuiteRun(ctx), types.SuiteInfo)) {
  case suite_runs {
    [] -> list.reverse(acc_rev)
    [suite_run, ..rest] ->
      suite_runs_with_infos(rest, [
        #(suite_run, suite_info_from_suite(suite_run.suite)),
        ..acc_rev
      ])
  }
}

fn suite_info_of_pair(
  pair: #(SuiteRun(ctx), types.SuiteInfo),
) -> types.SuiteInfo {
  pair.1
}

fn suite_info_from_suite(suite: TestSuite(ctx)) -> types.SuiteInfo {
  let tests_rev = collect_test_infos(root_group(suite), [], [], [])
  let tests = list.reverse(tests_rev)
  let source = suite_source_from_tests(tests)
  types.SuiteInfo(name: suite.name, tests: tests, source: source)
}

fn collect_test_infos(
  node: Node(ctx),
  scope: List(String),
  inherited_tags: List(String),
  acc_rev: List(types.TestInfo),
) -> List(types.TestInfo) {
  case node {
    Test(
      name: name,
      tags: tags,
      kind: kind,
      run: _run,
      timeout_ms: _timeout_ms,
      source: source,
    ) -> {
      let effective_tags = list.append(inherited_tags, tags)
      let info =
        types.TestInfo(
          name: name,
          groups: scope,
          tags: effective_tags,
          kind: kind,
          source: source,
        )
      [info, ..acc_rev]
    }
    Group(name: name, tags: tags, children: children) -> {
      let next_scope = list.append(scope, [name])
      let next_tags = list.append(inherited_tags, tags)
      collect_test_infos_children(children, next_scope, next_tags, acc_rev)
    }
    _ -> acc_rev
  }
}

fn collect_test_infos_children(
  children: List(Node(ctx)),
  scope: List(String),
  inherited_tags: List(String),
  acc_rev: List(types.TestInfo),
) -> List(types.TestInfo) {
  case children {
    [] -> acc_rev
    [child, ..rest] ->
      collect_test_infos_children(
        rest,
        scope,
        inherited_tags,
        collect_test_infos(child, scope, inherited_tags, acc_rev),
      )
  }
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

/// A suite-level hook with the input that it gets, so that the owner
/// process of its scope can run it.
type SuiteHookCall(input) {
  SuiteHookCall(hook: fn(input) -> Result(Nil, String), input: input)
}

fn call_suite_hook(call: SuiteHookCall(input)) -> Result(Nil, String) {
  call.hook(call.input)
}

/// The owner process of a suite-level scope: all suites, or one suite.
type SuiteOwner(input) =
  Owner(SuiteHookCall(input), Result(Nil, String))

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

/// The owner process of a suite-level scope whose set-up hooks returned.
type SuiteScopeOwner(input) {
  /// The owner was alive at the last check.
  SuiteOwnerAlive(owner: SuiteOwner(input))
  /// The owner stopped with `reason`. The suites of the scope that have
  /// not started do not run, and its tear-down hooks run in a new owner.
  /// `not_run` is the full name of each test that it did not run, in the
  /// order of the run.
  SuiteOwnerGone(reason: String, not_run: List(List(String)))
}

fn alive_suite_owner(
  owner: Option(SuiteOwner(input)),
) -> Option(SuiteScopeOwner(input)) {
  case owner {
    Some(owner) -> Some(SuiteOwnerAlive(owner: owner))
    None -> None
  }
}

/// Look again at an owner that was alive. The check takes the down
/// message of a stopped owner, so its reason is kept in `SuiteOwnerGone`.
fn refresh_suite_owner(
  owner: Option(SuiteScopeOwner(input)),
) -> Option(SuiteScopeOwner(input)) {
  case owner {
    Some(SuiteOwnerAlive(owner: alive)) ->
      Some(checked_suite_owner(sandbox.check_owner(alive)))
    _ -> owner
  }
}

fn checked_suite_owner(
  checked: Result(SuiteOwner(input), String),
) -> SuiteScopeOwner(input) {
  case checked {
    Ok(alive) -> SuiteOwnerAlive(owner: alive)
    Error(reason) -> SuiteOwnerGone(reason: reason, not_run: [])
  }
}

/// The result of the suite-level set-up hooks of a scope, by cause.
type SuiteSetUpResult(input) {
  /// Every hook returned `Ok`, or the owner process exited. `owner` is
  /// `SuiteOwnerGone` when the owner exited: the set-up stopped, so the
  /// tests of the scope are not run, and its tear-down hooks run in a new
  /// owner. `owner` is `None` when the scope has no set-up hook.
  SuiteSetUpRan(owner: Option(SuiteScopeOwner(input)))
  /// A hook returned `Error`, crashed inside the hook call, or timed out.
  /// `message` names the scope for a crash or a timeout. `owner` is the
  /// owner when it is still alive.
  SuiteSetUpFailed(owner: Option(SuiteOwner(input)), message: String)
}

/// Run suite-level set-up hooks in order, in the owner process of their
/// scope, and stop at the first failure or when the owner exits. The
/// first hook starts the owner, so a resource that a hook starts lives
/// until the owner stops after the tear-down hooks. Each hook gets the
/// timeout of the scope.
///
/// A hook that returns `Error`, crashes or times out is a failure of the
/// hook. An owner process that exits, while a hook runs or between two
/// hooks, stops the set-up.
fn run_suite_level_hooks(
  set_up: SuiteSetUp(input),
  owner: Option(SuiteOwner(input)),
) -> SuiteSetUpResult(input) {
  case set_up.hooks {
    [] -> SuiteSetUpRan(owner: alive_suite_owner(owner))
    [hook, ..rest] ->
      suite_set_up_result(
        SuiteSetUp(..set_up, hooks: rest),
        sandbox.run_in_owner(
          owner,
          set_up.timeout_ms,
          call_suite_hook,
          SuiteHookCall(hook: hook, input: set_up.input),
        ),
      )
  }
}

fn suite_set_up_result(
  rest: SuiteSetUp(input),
  owner_result: OwnerResult(SuiteHookCall(input), Result(Nil, String)),
) -> SuiteSetUpResult(input) {
  case owner_result {
    OwnerReturned(owner: owner, value: Ok(Nil)) ->
      run_suite_level_hooks(rest, Some(owner))
    OwnerReturned(owner: owner, value: Error(message)) ->
      SuiteSetUpFailed(owner: Some(owner), message: message)
    OwnerCaught(owner: owner, reason: reason) ->
      SuiteSetUpFailed(
        owner: Some(owner),
        message: suite_hook_crash_message(rest.scope, reason),
      )
    OwnerTimedOut ->
      SuiteSetUpFailed(
        owner: None,
        message: suite_hook_timeout_message(rest.scope),
      )
    OwnerExited(reason: reason) | OwnerLost(reason: reason) ->
      SuiteSetUpRan(owner: Some(SuiteOwnerGone(reason: reason, not_run: [])))
  }
}

/// End a suite-level scope: report an owner that stopped while the suites
/// ran, run every tear-down hook (in the owner while it is alive, else in
/// a new owner), then stop the owner. Gives the failures in the order that
/// they happened.
fn finish_suite_scope(
  tear_down: SuiteTearDown(input),
  owner: Option(SuiteScopeOwner(input)),
) -> List(TeardownFailure) {
  case owner, tear_down.hooks {
    None, _ -> run_suite_teardown(tear_down, None, [])
    Some(SuiteOwnerGone(reason: reason, not_run: not_run)), _ ->
      run_suite_teardown(tear_down, None, [
        suite_setup_stopped(tear_down, reason, not_run),
      ])
    Some(SuiteOwnerAlive(owner: alive)), [] ->
      stop_checked_suite_owner(tear_down, sandbox.check_owner(alive))
    Some(SuiteOwnerAlive(owner: alive)), _ ->
      run_suite_teardown(tear_down, Some(alive), [])
  }
}

/// Run the tear-down hooks, then stop the last owner.
fn run_suite_teardown(
  tear_down: SuiteTearDown(input),
  owner: Option(SuiteOwner(input)),
  failures_rev: List(TeardownFailure),
) -> List(TeardownFailure) {
  let #(last_owner, next_failures_rev) =
    run_suite_teardown_hooks(tear_down, tear_down.hooks, owner, failures_rev)
  let _stopped = option.map(last_owner, sandbox.stop_owner)
  list.reverse(next_failures_rev)
}

/// Stop the owner of a scope with no tear-down hook, or report that it
/// stopped already.
fn stop_checked_suite_owner(
  tear_down: SuiteTearDown(input),
  checked: Result(SuiteOwner(input), String),
) -> List(TeardownFailure) {
  case checked {
    Ok(owner) -> {
      sandbox.stop_owner(owner)
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
/// or an exit of the owner, the next hook runs in a new owner. An owner
/// that stopped before a hook started means that the set-up stopped: the
/// hook runs again in a new owner, so it never stays not run.
fn run_suite_teardown_hooks(
  tear_down: SuiteTearDown(input),
  hooks: List(fn(input) -> Result(Nil, String)),
  owner: Option(SuiteOwner(input)),
  failures_rev: List(TeardownFailure),
) -> #(Option(SuiteOwner(input)), List(TeardownFailure)) {
  case hooks {
    [] -> #(owner, failures_rev)
    [hook, ..rest] ->
      suite_tear_down_result(
        tear_down,
        hook,
        rest,
        sandbox.run_in_owner(
          owner,
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
  owner_result: OwnerResult(SuiteHookCall(input), Result(Nil, String)),
  failures_rev: List(TeardownFailure),
) -> #(Option(SuiteOwner(input)), List(TeardownFailure)) {
  case owner_result {
    OwnerReturned(owner: owner, value: Ok(Nil)) ->
      run_suite_teardown_hooks(tear_down, rest, Some(owner), failures_rev)
    OwnerReturned(owner: owner, value: Error(message)) ->
      run_suite_teardown_hooks(
        tear_down,
        rest,
        Some(owner),
        add_teardown_failure(tear_down, message, failures_rev),
      )
    OwnerCaught(owner: owner, reason: reason) ->
      run_suite_teardown_hooks(
        tear_down,
        rest,
        Some(owner),
        add_teardown_failure(
          tear_down,
          suite_hook_crash_message(tear_down.scope, reason),
          failures_rev,
        ),
      )
    OwnerTimedOut ->
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
    OwnerExited(reason: reason) ->
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
    OwnerLost(reason: reason) ->
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
  suite_runs: List(#(SuiteRun(ctx), types.SuiteInfo)),
  default_config: parallel.ParallelConfig,
  progress_reporter: Option(progress.ProgressReporter),
  output: Output,
  total: Int,
  completed: Int,
  before_each_suite_hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  after_each_suite_hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  runner_before_each_test: List(fn(types.TestInfo, ctx) -> Result(ctx, String)),
  runner_after_each_test: List(fn(types.TestInfo, ctx) -> Result(Nil, String)),
  collected: Collected,
  all_suites_owner: Option(SuiteScopeOwner(List(types.SuiteInfo))),
) -> #(Collected, Int, Option(SuiteScopeOwner(List(types.SuiteInfo)))) {
  let checked_owner = refresh_suite_owner(all_suites_owner)
  case suite_runs {
    [] -> #(collected, completed, checked_owner)
    [#(SuiteRun(suite: suite, config_override: override), suite_info), ..rest] -> {
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
        )
      let #(suite_collected, completed_after_suite, owner_after_suite) =
        run_suite_in_run(
          suite_run,
          before_each_suite_hooks,
          after_each_suite_hooks,
          checked_owner,
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
        Collected(
          tests: list.append(collected.tests, suite_collected.tests),
          teardown_failures: list.append(
            collected.teardown_failures,
            suite_collected.teardown_failures,
          ),
        ),
        owner_after_suite,
      )
    }
  }
}

/// What stays the same while the tests of one suite run.
type SuiteTests(ctx) {
  SuiteTests(
    suite: TestSuite(ctx),
    config: parallel.ParallelConfig,
    info: types.SuiteInfo,
    progress_reporter: Option(progress.ProgressReporter),
    output: Output,
    total: Int,
    completed: Int,
    runner_before_each_test: List(
      fn(types.TestInfo, ctx) -> Result(ctx, String),
    ),
    runner_after_each_test: List(fn(types.TestInfo, ctx) -> Result(Nil, String)),
  )
}

/// Run one suite in the scope of the whole run. After the owner of the
/// run stopped, no suite-level hook runs.
fn run_suite_in_run(
  suite_run: SuiteTests(ctx),
  before_each_suite_hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  after_each_suite_hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  all_suites_owner: Option(SuiteScopeOwner(List(types.SuiteInfo))),
) -> #(Collected, Int, Option(SuiteScopeOwner(List(types.SuiteInfo)))) {
  case all_suites_owner {
    Some(SuiteOwnerGone(..)) ->
      run_suite_after_run_setup_stopped(suite_run, all_suites_owner)
    _ ->
      run_one_suite(
        suite_run,
        before_each_suite_hooks,
        after_each_suite_hooks,
        all_suites_owner,
      )
  }
}

/// Run a suite after the owner of the whole run stopped. No suite-level
/// hook runs, and the executor gives `SetupFailed` to each test.
fn run_suite_after_run_setup_stopped(
  suite_run: SuiteTests(ctx),
  all_suites_owner: Option(SuiteScopeOwner(List(types.SuiteInfo))),
) -> #(Collected, Int, Option(SuiteScopeOwner(List(types.SuiteInfo)))) {
  let result =
    run_suite_tests(
      suite_run,
      outer_setup(BeforeAllSuitesHook, [], all_suites_owner),
    )
  #(
    Collected(
      tests: result.results,
      teardown_failures: result.teardown_failures,
    ),
    result.completed,
    stopped_suite_owner(
      all_suites_owner,
      BeforeAllSuitesHook,
      result.outer_setups,
    ),
  )
}

/// Run `before_each_suite`, then the tests of one suite, then
/// `after_each_suite`. A failed `before_each_suite` hook gives
/// `SetupFailed` to every test of the suite. The executor checks the owner
/// of the whole run and the owner of the suite before each test starts.
fn run_one_suite(
  suite_run: SuiteTests(ctx),
  before_each_suite_hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  after_each_suite_hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  all_suites_owner: Option(SuiteScopeOwner(List(types.SuiteInfo))),
) -> #(Collected, Int, Option(SuiteScopeOwner(List(types.SuiteInfo)))) {
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
  let #(tests_collected, completed_after_tests, all_owner, suite_owner) = case
    before_result
  {
    SuiteSetUpFailed(owner: owner, message: message) -> {
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
        all_suites_owner,
        alive_suite_owner(owner),
      )
    }
    SuiteSetUpRan(owner: suite_owner) -> {
      let result =
        run_suite_tests(
          suite_run,
          list.append(
            outer_setup(BeforeAllSuitesHook, [], all_suites_owner),
            outer_setup(BeforeEachSuiteHook, suite_scope, suite_owner),
          ),
        )
      #(
        Collected(
          tests: result.results,
          teardown_failures: result.teardown_failures,
        ),
        result.completed,
        stopped_suite_owner(
          all_suites_owner,
          BeforeAllSuitesHook,
          result.outer_setups,
        ),
        stopped_suite_owner(
          suite_owner,
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
      suite_owner,
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
    all_owner,
  )
}

/// Run the tests of one suite in the executor, inside `outer_setups`.
fn run_suite_tests(
  suite_run: SuiteTests(ctx),
  outer_setups: List(parallel.OuterSetup),
) -> parallel.RunRootParallelWithReporterResult {
  parallel.run_root_parallel_with_reporter(
    parallel.RunRootParallelWithReporterConfig(
      config: suite_run.config,
      suite: suite_run.suite,
      progress_reporter: suite_run.progress_reporter,
      write: output_out(suite_run.output),
      total: suite_run.total,
      completed: suite_run.completed,
      runner_before_each_test: suite_run.runner_before_each_test,
      runner_after_each_test: suite_run.runner_after_each_test,
      outer_setups: outer_setups,
    ),
  )
}

/// The suite-level set-up of `owner` as the executor sees it: no set-up
/// when it has no owner.
fn outer_setup(
  set_up: SetUpHook,
  scope: List(String),
  owner: Option(SuiteScopeOwner(input)),
) -> List(parallel.OuterSetup) {
  case owner {
    None -> []
    Some(SuiteOwnerAlive(owner: alive)) -> [
      parallel.SetupRunning(set_up: set_up, groups: scope, check_owner: fn() {
        check_suite_owner(alive)
      }),
    ]
    Some(SuiteOwnerGone(reason: reason, not_run: not_run)) -> [
      parallel.SetupStopped(
        set_up: set_up,
        groups: scope,
        reason: reason,
        not_run: not_run,
      ),
    ]
  }
}

fn check_suite_owner(owner: SuiteOwner(input)) -> Result(Nil, String) {
  sandbox.check_owner(owner)
  |> result.replace(Nil)
}

/// The owner after the executor ran: gone when the executor saw the
/// set-up `set_up` stopped. The check of the executor took the down message of
/// the owner, so its reason comes from `outer_setups`, with the tests that
/// the executor did not run because of it.
fn stopped_suite_owner(
  owner: Option(SuiteScopeOwner(input)),
  set_up: SetUpHook,
  outer_setups: List(parallel.OuterSetup),
) -> Option(SuiteScopeOwner(input)) {
  case owner, find_stopped_owner(outer_setups, set_up) {
    Some(_), Ok(gone) -> Some(gone)
    _, _ -> owner
  }
}

/// The first of `outer_setups` that says the set-up `set_up` stopped, as
/// a gone owner.
fn find_stopped_owner(
  outer_setups: List(parallel.OuterSetup),
  set_up: SetUpHook,
) -> Result(SuiteScopeOwner(input), Nil) {
  case outer_setups {
    [] -> Error(Nil)
    [outer_setup, ..rest] ->
      stopped_owner_or_next(stopped_owner(outer_setup, set_up), rest, set_up)
  }
}

fn stopped_owner_or_next(
  found: Result(SuiteScopeOwner(input), Nil),
  rest: List(parallel.OuterSetup),
  set_up: SetUpHook,
) -> Result(SuiteScopeOwner(input), Nil) {
  case found {
    Ok(gone) -> Ok(gone)
    Error(Nil) -> find_stopped_owner(rest, set_up)
  }
}

fn stopped_owner(
  outer_setup: parallel.OuterSetup,
  set_up: SetUpHook,
) -> Result(SuiteScopeOwner(input), Nil) {
  case outer_setup {
    parallel.SetupStopped(
      set_up: stopped,
      groups: _,
      reason: reason,
      not_run: not_run,
    )
      if stopped == set_up
    -> Ok(SuiteOwnerGone(reason: reason, not_run: not_run))
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

fn silent_output() -> Output {
  Output(out: discard_output, error: discard_output)
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
    True -> {
      let _ = stop_with_status(1)
      Nil
    }
    False -> Nil
  }
}

fn apply_test_filter(
  suite_runs: List(SuiteRun(ctx)),
  predicate: Option(fn(TestInfo) -> Bool),
) -> List(SuiteRun(ctx)) {
  case predicate {
    None -> suite_runs
    Some(p) -> filter_suite_runs(suite_runs, p, [])
  }
}

fn filter_suite_runs(
  suite_runs: List(SuiteRun(ctx)),
  predicate: fn(TestInfo) -> Bool,
  acc_rev: List(SuiteRun(ctx)),
) -> List(SuiteRun(ctx)) {
  case suite_runs {
    [] -> list.reverse(acc_rev)
    [SuiteRun(suite: suite, config_override: override), ..rest] -> {
      let #(maybe, _has_tests) = filter_root(suite, predicate)
      case maybe {
        None -> filter_suite_runs(rest, predicate, acc_rev)
        Some(filtered) ->
          filter_suite_runs(rest, predicate, [
            SuiteRun(suite: filtered, config_override: override),
            ..acc_rev
          ])
      }
    }
  }
}

fn filter_root(
  suite: TestSuite(ctx),
  predicate: fn(TestInfo) -> Bool,
) -> #(Option(TestSuite(ctx)), Bool) {
  let #(children, has_tests) =
    filter_children(
      suite.children,
      [suite.name],
      suite.tags,
      predicate,
      [],
      False,
    )
  case has_tests {
    True -> #(Some(Root(..suite, children: children)), True)
    False -> #(None, False)
  }
}

/// The top-level group of a suite, as a node.
fn root_group(suite: TestSuite(ctx)) -> Node(ctx) {
  Group(name: suite.name, tags: suite.tags, children: suite.children)
}

fn filter_node(
  node: Node(ctx),
  scope: List(String),
  inherited_tags: List(String),
  predicate: fn(TestInfo) -> Bool,
) -> #(Option(Node(ctx)), Bool) {
  case node {
    Test(
      name: name,
      tags: tags,
      kind: kind,
      run: run,
      timeout_ms: timeout_ms,
      source: source,
    ) -> {
      let effective_tags = list.append(inherited_tags, tags)
      let info =
        types.TestInfo(
          name: name,
          groups: scope,
          tags: effective_tags,
          kind: kind,
          source: source,
        )
      case predicate(info) {
        True -> #(
          Some(Test(
            name: name,
            tags: tags,
            kind: kind,
            run: run,
            timeout_ms: timeout_ms,
            source: source,
          )),
          True,
        )
        False -> #(None, False)
      }
    }

    Group(name: name, tags: tags, children: children) -> {
      let next_scope = list.append(scope, [name])
      let next_tags = list.append(inherited_tags, tags)
      let #(filtered_children, has_tests) =
        filter_children(children, next_scope, next_tags, predicate, [], False)
      case has_tests {
        True -> #(
          Some(Group(name: name, tags: tags, children: filtered_children)),
          True,
        )
        False -> #(None, False)
      }
    }

    BeforeAll(..) -> #(Some(node), False)
    BeforeEach(..) -> #(Some(node), False)
    AfterEach(..) -> #(Some(node), False)
    AfterAll(..) -> #(Some(node), False)
  }
}

fn filter_children(
  children: List(Node(ctx)),
  scope: List(String),
  inherited_tags: List(String),
  predicate: fn(TestInfo) -> Bool,
  acc_rev: List(Node(ctx)),
  has_tests: Bool,
) -> #(List(Node(ctx)), Bool) {
  case children {
    [] -> #(list.reverse(acc_rev), has_tests)
    [child, ..rest] -> {
      let #(maybe_child, child_has_tests) =
        filter_node(child, scope, inherited_tags, predicate)
      let next_has_tests = has_tests || child_has_tests
      case maybe_child {
        None ->
          filter_children(
            rest,
            scope,
            inherited_tags,
            predicate,
            acc_rev,
            next_has_tests,
          )
        Some(kept) ->
          filter_children(
            rest,
            scope,
            inherited_tags,
            predicate,
            [kept, ..acc_rev],
            next_has_tests,
          )
      }
    }
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

fn write_results_reporters(
  reporters: List(reporter_types.ResultsReporter),
  report: RunReport,
  output: Output,
) -> Nil {
  write_results_reporters_loop(reporters, report, output_out(output))
}

fn write_results_reporters_loop(
  reporters: List(reporter_types.ResultsReporter),
  report: RunReport,
  write: fn(String) -> Nil,
) -> Nil {
  case reporters {
    [] -> Nil
    [reporter, ..rest] -> {
      write(render_results_reporter(reporter, report))
      write_results_reporters_loop(rest, report, write)
    }
  }
}

fn render_results_reporter(
  reporter: reporter_types.ResultsReporter,
  report: RunReport,
) -> String {
  case reporter {
    reporter_types.Bdd(config) -> bdd.render(config, report)
    reporter_types.Json(config) -> json.render(config, report)
  }
}

fn output_out(output: Output) -> fn(String) -> Nil {
  let Output(out: out, error: _error) = output
  out
}

fn count_total_tests(suite_runs: List(SuiteRun(ctx))) -> Int {
  count_total_tests_from_list(suite_runs, 0)
}

fn count_total_tests_from_list(
  suite_runs: List(SuiteRun(ctx)),
  acc: Int,
) -> Int {
  case suite_runs {
    [] -> acc
    [SuiteRun(suite: suite, config_override: _), ..rest] ->
      count_total_tests_from_list(
        rest,
        acc + count_tests_in_suite(root_group(suite)),
      )
  }
}

fn count_tests_in_suite(node: Node(ctx)) -> Int {
  case node {
    Test(..) -> 1
    Group(_, _, children) -> count_tests_in_children(children, 0)
    _ -> 0
  }
}

fn count_tests_in_children(children: List(Node(ctx)), acc: Int) -> Int {
  case children {
    [] -> acc
    [child, ..rest] ->
      count_tests_in_children(rest, acc + count_tests_in_suite(child))
  }
}

// ============================================================================
// Suite run list helpers (no anonymous fns)
// ============================================================================

fn suites_to_suite_runs_default(
  suites: List(TestSuite(ctx)),
  acc_rev: List(SuiteRun(ctx)),
) -> List(SuiteRun(ctx)) {
  case suites {
    [] -> list.reverse(acc_rev)
    [suite, ..rest] ->
      suites_to_suite_runs_default(rest, [
        SuiteRun(suite: suite, config_override: None),
        ..acc_rev
      ])
  }
}

fn suites_to_suite_runs_with_override(
  config: parallel.ParallelConfig,
  suites: List(TestSuite(ctx)),
  acc_rev: List(SuiteRun(ctx)),
) -> List(SuiteRun(ctx)) {
  case suites {
    [] -> list.reverse(acc_rev)
    [suite, ..rest] ->
      suites_to_suite_runs_with_override(config, rest, [
        SuiteRun(suite: suite, config_override: Some(config)),
        ..acc_rev
      ])
  }
}

fn append_suite_runs_default(
  existing: List(SuiteRun(ctx)),
  suites: List(TestSuite(ctx)),
) -> List(SuiteRun(ctx)) {
  list.append(existing, suites_to_suite_runs_default(suites, []))
}

fn append_suite_runs_with_override(
  existing: List(SuiteRun(ctx)),
  config: parallel.ParallelConfig,
  suites: List(TestSuite(ctx)),
) -> List(SuiteRun(ctx)) {
  list.append(existing, suites_to_suite_runs_with_override(config, suites, []))
}

/// What `init:stop/1` gives back: the atom `ok`. The BEAM stops after the
/// call returns, when the init process shuts it down.
type StopRequested

/// Ask the BEAM to shut down and then exit with `status`. Gleam stops a
/// program in the same way: `init:stop(0)` when `main` returns, and
/// `init:stop(1)` when it crashes. The first request wins, so the status
/// stays the same when `main` returns after this call.
@external(erlang, "init", "stop")
fn stop_with_status(status: Int) -> StopRequested
