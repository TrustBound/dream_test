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

import dream_test/parallel
import dream_test/reporters/bdd
import dream_test/reporters/json
import dream_test/reporters/progress
import dream_test/reporters/types as reporter_types
import dream_test/types.{
  type AssertionFailure, type Node, type TestResult, type TestSuite, AfterAll,
  AfterEach, BeforeAll, BeforeEach, Failed, Group, Root, SetupFailed, Test,
  TimedOut, Unit,
}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}

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
/// Tests that exceed the timeout are killed and reported as `TimedOut`.
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

/// Exit the BEAM with a non-zero code if any tests fail.
///
/// Useful for CI pipelines.
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
/// Results reporters receive the full traversal-ordered results list from the
/// `RunFinished` event, so their output is deterministic under parallel execution.
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
///   io.println("starting " <> string.join(info.full_name, " > "))
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
/// The hook receives `types.TestInfo` and the current context value.
/// If it returns `Error("...")`, the test is marked `Failed`.
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
/// The hook receives `types.SuiteInfo` for the suite about to run.
/// If it returns `Error("...")`, all tests in that suite are marked `Failed`
/// and the suite is skipped.
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
/// The hook receives `types.SuiteInfo` for the suite that just ran.
/// If it returns `Error("...")`, a synthetic failure result is appended.
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
/// The hook receives the full list of `SuiteInfo` after filtering.
/// If it returns `Error("...")`, all selected tests are marked `Failed`
/// and the run short-circuits.
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
/// The hook receives the full list of `SuiteInfo` after filtering.
/// If it returns `Error("...")`, a synthetic failure result is appended.
pub fn after_all_suites(
  builder builder: RunBuilder(ctx),
  hook hook: fn(List(types.SuiteInfo)) -> Result(Nil, String),
) -> RunBuilder(ctx) {
  RunBuilder(
    ..builder,
    runner_after_all_suites: list.append(builder.runner_after_all_suites, [hook]),
  )
}

/// Run all suites and return a list of `TestResult`.
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
/// A list of `TestResult` values, in deterministic order.
pub fn run(builder builder: RunBuilder(ctx)) -> List(TestResult) {
  let selected_runs = apply_test_filter(builder.suite_runs, builder.test_filter)
  let total = count_total_tests(selected_runs)
  let suite_infos = suite_infos_from_runs(selected_runs, [])

  let output = case builder.output {
    Some(output) -> output
    None -> default_output()
  }

  let completed0 = 0
  let progress_reporter0 = builder.progress_reporter
  let completed1 = case progress_reporter0 {
    None -> completed0
    Some(progress_reporter) -> {
      write_progress_event(
        progress_reporter,
        reporter_types.RunStarted(total: total),
        output,
      )
      completed0
    }
  }

  let before_all_result =
    run_before_all_suites_hooks(builder.runner_before_all_suites, suite_infos)

  let #(results, completed2, progress_reporter1) = case before_all_result {
    Ok(_) ->
      run_suites_with_hooks(
        selected_runs,
        suite_infos,
        builder.config,
        progress_reporter0,
        output,
        total,
        completed1,
        builder.runner_before_each_suite,
        builder.runner_after_each_suite,
        builder.runner_before_each_test,
        builder.runner_after_each_test,
        [],
      )
    Error(message) -> {
      let failures =
        build_failed_results_from_suites(
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
          failures,
        )
      let results_with_after_all =
        apply_after_all_suites_hooks(
          builder.runner_after_all_suites,
          suite_infos,
          failures,
        )
      #(results_with_after_all, completed_after_failures, progress_reporter0)
    }
  }

  let final_results = case before_all_result {
    Ok(_) ->
      apply_after_all_suites_hooks(
        builder.runner_after_all_suites,
        suite_infos,
        results,
      )
    Error(_) -> results
  }

  case progress_reporter1 {
    None -> Nil
    Some(progress_reporter) ->
      write_progress_event(
        progress_reporter,
        reporter_types.RunFinished(
          completed: completed2,
          total: total,
          results: final_results,
        ),
        output,
      )
  }

  write_results_reporters(builder.results_reporters, final_results, output)

  maybe_exit_on_failure(builder.should_exit_on_failure, final_results)

  final_results
}

fn suite_infos_from_runs(
  suite_runs: List(SuiteRun(ctx)),
  acc_rev: List(types.SuiteInfo),
) -> List(types.SuiteInfo) {
  case suite_runs {
    [] -> list.reverse(acc_rev)
    [SuiteRun(suite: suite, config_override: _), ..rest] ->
      suite_infos_from_runs(rest, [suite_info_from_suite(suite), ..acc_rev])
  }
}

fn suite_info_from_suite(suite: TestSuite(ctx)) -> types.SuiteInfo {
  let Root(seed: _seed, tree: tree) = suite
  let tests_rev = collect_test_infos(tree, [], [], [])
  let tests = list.reverse(tests_rev)
  let source = suite_source_from_tests(tests)
  types.SuiteInfo(
    name: suite_name_from_tree(tree),
    tests: tests,
    source: source,
  )
}

fn suite_name_from_tree(tree: Node(ctx)) -> String {
  case tree {
    Group(name: name, tags: _tags, children: _children) -> name
    _ -> "<unknown-suite>"
  }
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
      let full_name = list.append(scope, [name])
      let effective_tags = list.append(inherited_tags, tags)
      let info =
        types.TestInfo(
          name: name,
          full_name: full_name,
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
        full_name: _full_name,
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
        full_name: _full_name,
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

fn run_before_all_suites_hooks(
  hooks: List(fn(List(types.SuiteInfo)) -> Result(Nil, String)),
  suites: List(types.SuiteInfo),
) -> Result(Nil, String) {
  case hooks {
    [] -> Ok(Nil)
    [hook, ..rest] ->
      case hook(suites) {
        Ok(_) -> run_before_all_suites_hooks(rest, suites)
        Error(message) -> Error(message)
      }
  }
}

fn run_before_each_suite_hooks(
  hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  suite: types.SuiteInfo,
) -> Result(Nil, String) {
  case hooks {
    [] -> Ok(Nil)
    [hook, ..rest] ->
      case hook(suite) {
        Ok(_) -> run_before_each_suite_hooks(rest, suite)
        Error(message) -> Error(message)
      }
  }
}

fn run_after_each_suite_hooks(
  hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  suite: types.SuiteInfo,
) -> Result(Nil, String) {
  case hooks {
    [] -> Ok(Nil)
    [hook, ..rest] ->
      case hook(suite) {
        Ok(_) -> run_after_each_suite_hooks(rest, suite)
        Error(message) -> Error(message)
      }
  }
}

fn run_after_all_suites_hooks(
  hooks: List(fn(List(types.SuiteInfo)) -> Result(Nil, String)),
  suites: List(types.SuiteInfo),
) -> Result(Nil, String) {
  case hooks {
    [] -> Ok(Nil)
    [hook, ..rest] ->
      case hook(suites) {
        Ok(_) -> run_after_all_suites_hooks(rest, suites)
        Error(message) -> Error(message)
      }
  }
}

fn run_suites_with_hooks(
  suite_runs: List(SuiteRun(ctx)),
  suite_infos: List(types.SuiteInfo),
  default_config: parallel.ParallelConfig,
  progress_reporter: Option(progress.ProgressReporter),
  output: Output,
  total: Int,
  completed: Int,
  before_each_suite_hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  after_each_suite_hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  runner_before_each_test: List(fn(types.TestInfo, ctx) -> Result(ctx, String)),
  runner_after_each_test: List(fn(types.TestInfo, ctx) -> Result(Nil, String)),
  acc: List(TestResult),
) -> #(List(TestResult), Int, Option(progress.ProgressReporter)) {
  case suite_runs, suite_infos {
    [], [] -> #(acc, completed, progress_reporter)
    [SuiteRun(suite: suite, config_override: override), ..rest],
      [suite_info, ..rest_infos]
    -> {
      let before_result =
        run_before_each_suite_hooks(before_each_suite_hooks, suite_info)
      case before_result {
        Error(message) -> {
          let failures =
            build_failed_results_from_tests(
              suite_info.tests,
              "before_each_suite",
              message,
            )
          let completed_after_failures =
            emit_test_finished_progress_results(
              progress_reporter,
              output,
              completed,
              total,
              failures,
            )
          let acc_with_failures = list.append(acc, failures)
          let acc_after_after_each =
            apply_after_each_suite_hooks(
              after_each_suite_hooks,
              suite_info,
              acc_with_failures,
            )
          run_suites_with_hooks(
            rest,
            rest_infos,
            default_config,
            progress_reporter,
            output,
            total,
            completed_after_failures,
            before_each_suite_hooks,
            after_each_suite_hooks,
            runner_before_each_test,
            runner_after_each_test,
            acc_after_after_each,
          )
        }
        Ok(_) -> {
          let suite_config = suite_run_config(default_config, override)
          let parallel_result =
            parallel.run_root_parallel_with_reporter(
              parallel.RunRootParallelWithReporterConfig(
                config: suite_config,
                suite: suite,
                progress_reporter: progress_reporter,
                write: output_out(output),
                total: total,
                completed: completed,
                runner_before_each_test: runner_before_each_test,
                runner_after_each_test: runner_after_each_test,
              ),
            )
          let parallel.RunRootParallelWithReporterResult(
            results: results,
            completed: completed_after_suite,
            progress_reporter: next_progress_reporter,
          ) = parallel_result
          let acc_with_results = list.append(acc, results)
          let acc_after_after_each =
            apply_after_each_suite_hooks(
              after_each_suite_hooks,
              suite_info,
              acc_with_results,
            )
          run_suites_with_hooks(
            rest,
            rest_infos,
            default_config,
            next_progress_reporter,
            output,
            total,
            completed_after_suite,
            before_each_suite_hooks,
            after_each_suite_hooks,
            runner_before_each_test,
            runner_after_each_test,
            acc_after_after_each,
          )
        }
      }
    }
    _, _ -> #(acc, completed, progress_reporter)
  }
}

fn apply_after_each_suite_hooks(
  hooks: List(fn(types.SuiteInfo) -> Result(Nil, String)),
  suite_info: types.SuiteInfo,
  results: List(TestResult),
) -> List(TestResult) {
  case run_after_each_suite_hooks(hooks, suite_info) {
    Ok(_) -> results
    Error(message) ->
      list.append(results, [
        after_each_suite_failure_result(suite_info, message),
      ])
  }
}

fn apply_after_all_suites_hooks(
  hooks: List(fn(List(types.SuiteInfo)) -> Result(Nil, String)),
  suites: List(types.SuiteInfo),
  results: List(TestResult),
) -> List(TestResult) {
  case run_after_all_suites_hooks(hooks, suites) {
    Ok(_) -> results
    Error(message) ->
      list.append(results, [after_all_suites_failure_result(message)])
  }
}

fn build_failed_results_from_suites(
  suites: List(types.SuiteInfo),
  operator: String,
  message: String,
) -> List(TestResult) {
  build_failed_results_from_suites_rev(suites, operator, message, [])
  |> list.reverse()
}

fn build_failed_results_from_suites_rev(
  suites: List(types.SuiteInfo),
  operator: String,
  message: String,
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case suites {
    [] -> acc_rev
    [suite, ..rest] ->
      build_failed_results_from_suites_rev(
        rest,
        operator,
        message,
        build_failed_results_from_tests_rev(
          suite.tests,
          operator,
          message,
          acc_rev,
        ),
      )
  }
}

fn build_failed_results_from_tests(
  tests: List(types.TestInfo),
  operator: String,
  message: String,
) -> List(TestResult) {
  build_failed_results_from_tests_rev(tests, operator, message, [])
  |> list.reverse()
}

fn build_failed_results_from_tests_rev(
  tests: List(types.TestInfo),
  operator: String,
  message: String,
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case tests {
    [] -> acc_rev
    [test_info, ..rest] ->
      build_failed_results_from_tests_rev(rest, operator, message, [
        failed_result_for_test_info(test_info, operator, message),
        ..acc_rev
      ])
  }
}

fn failed_result_for_test_info(
  info: types.TestInfo,
  operator: String,
  message: String,
) -> TestResult {
  let types.TestInfo(
    name: name,
    full_name: full_name,
    tags: tags,
    kind: kind,
    source: _source,
  ) = info
  types.TestResult(
    name: name,
    full_name: full_name,
    status: Failed,
    duration_ms: 0,
    tags: tags,
    failures: [hook_failure(operator, message)],
    kind: kind,
  )
}

fn after_all_suites_failure_result(message: String) -> TestResult {
  types.TestResult(
    name: "<after_all_suites>",
    full_name: ["<after_all_suites>"],
    status: Failed,
    duration_ms: 0,
    tags: [],
    failures: [hook_failure("after_all_suites", message)],
    kind: Unit,
  )
}

fn after_each_suite_failure_result(
  suite_info: types.SuiteInfo,
  message: String,
) -> TestResult {
  let types.SuiteInfo(name: name, tests: _tests, source: _source) = suite_info
  types.TestResult(
    name: "<after_each_suite>",
    full_name: [name, "<after_each_suite>"],
    status: Failed,
    duration_ms: 0,
    tags: [],
    failures: [hook_failure("after_each_suite", message)],
    kind: Unit,
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
        reporter_types.TestFinished(
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

fn maybe_exit_on_failure(should_exit: Bool, results: List(TestResult)) -> Nil {
  let should_halt = should_exit && has_failures(results)
  case should_halt {
    True -> halt(1)
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
  let Root(seed: seed, tree: tree) = suite
  let #(maybe_tree, has_tests) = filter_node(tree, [], [], predicate)
  case maybe_tree {
    None -> #(None, has_tests)
    Some(next_tree) -> #(Some(Root(seed: seed, tree: next_tree)), has_tests)
  }
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
      let full_name = list.append(scope, [name])
      let effective_tags = list.append(inherited_tags, tags)
      let info =
        types.TestInfo(
          name: name,
          full_name: full_name,
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

fn write_progress_event(
  reporter: progress.ProgressReporter,
  event: reporter_types.ReporterEvent,
  output: Output,
) -> Nil {
  case progress.handle_event(reporter, event) {
    None -> Nil
    Some(text) -> output_out(output)(text)
  }
}

fn write_results_reporters(
  reporters: List(reporter_types.ResultsReporter),
  results: List(TestResult),
  output: Output,
) -> Nil {
  write_results_reporters_loop(reporters, results, output_out(output))
}

fn write_results_reporters_loop(
  reporters: List(reporter_types.ResultsReporter),
  results: List(TestResult),
  write: fn(String) -> Nil,
) -> Nil {
  case reporters {
    [] -> Nil
    [reporter, ..rest] -> {
      write(render_results_reporter(reporter, results))
      write_results_reporters_loop(rest, results, write)
    }
  }
}

fn render_results_reporter(
  reporter: reporter_types.ResultsReporter,
  results: List(TestResult),
) -> String {
  case reporter {
    reporter_types.Bdd(config) -> bdd.render(config, results)
    reporter_types.Json(config) -> json.render(config, results)
  }
}

fn output_out(output: Output) -> fn(String) -> Nil {
  let Output(out: out, error: _error) = output
  out
}

fn count_total_tests(suite_runs: List(SuiteRun(ctx))) -> Int {
  count_total_tests_from_list(suite_runs, 0)
}

fn count_total_tests_from_list(suite_runs: List(SuiteRun(ctx)), acc: Int) -> Int {
  case suite_runs {
    [] -> acc
    [SuiteRun(suite: suite, config_override: _), ..rest] ->
      count_total_tests_from_list(rest, acc + count_tests_in_suite(suite.tree))
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

/// Return `True` if the list contains any failing statuses.
///
/// This treats `Failed`, `SetupFailed`, and `TimedOut` as failures.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
/// import dream_test/runner
/// import dream_test/unit.{describe, it}
///
/// pub fn tests() {
///   describe("has_failures", [
///     it("passes", fn() { Ok(succeed()) }),
///   ])
/// }
///
/// fn failing_suite() {
///   describe("failing suite", [
///     it("fails", fn() {
///       1
///       |> should
///       |> be_equal(2)
///       |> or_fail_with("intentional failure for has_failures example")
///     }),
///   ])
/// }
///
/// pub fn main() {
///   let results = runner.new([failing_suite()]) |> runner.run()
///
///   results
///   |> runner.has_failures()
///   |> should
///   |> be_equal(True)
///   |> or_fail_with("expected failures to be present")
/// }
/// ```
///
/// ## Parameters
///
/// - `results`: list of `TestResult` values returned by `runner.run`
///
/// ## Returns
///
/// `True` when any result has status `Failed`, `SetupFailed`, or `TimedOut`.
pub fn has_failures(results results: List(TestResult)) -> Bool {
  case results {
    [] -> False
    [r, ..rest] ->
      case r.status {
        Failed -> True
        SetupFailed -> True
        TimedOut -> True
        _ -> has_failures(rest)
      }
  }
}

@external(erlang, "erlang", "halt")
fn halt(exit_code: Int) -> Nil
