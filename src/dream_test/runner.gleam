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
////   runner.new([tests()])
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
  type Node, type TestKind, type TestResult, type TestSuite, AfterAll, AfterEach,
  BeforeAll, BeforeEach, Failed, Group, Root, SetupFailed, Test, TimedOut,
}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}

/// Lightweight information about a test, used for filtering what runs.
///
/// ## Fields
///
/// - `name`: the test’s local name (the one passed to `it("...", ...)`)
/// - `full_name`: the group path + test name (useful for fully-qualified filters)
/// - `tags`: effective tags (includes inherited group tags)
/// - `kind`: the `types.TestKind` (Unit, Gherkin, etc.)
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner.{type TestInfo}
/// import dream_test/unit.{describe, it, with_tags}
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
pub type TestInfo {
  TestInfo(
    name: String,
    full_name: List(String),
    tags: List(String),
    kind: TestKind,
  )
}

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
    suites: List(TestSuite(ctx)),
    config: parallel.ParallelConfig,
    test_filter: Option(fn(TestInfo) -> Bool),
    should_exit_on_failure: Bool,
    progress_reporter: Option(progress.ProgressReporter),
    results_reporters: List(reporter_types.ResultsReporter),
    output: Option(Output),
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
  RunBuilder(
    suites: suites,
    config: parallel.default_config(),
    test_filter: None,
    should_exit_on_failure: False,
    progress_reporter: None,
    results_reporters: [],
    output: None,
  )
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
  let selected_suites = apply_test_filter(builder.suites, builder.test_filter)
  let total = count_total_tests(selected_suites)

  let output = case builder.output {
    Some(output) -> output
    None -> default_output()
  }

  let completed0 = 0
  let completed1 = case builder.progress_reporter {
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

  let #(results, completed2) =
    run_suites_with_progress(
      selected_suites,
      builder.config,
      builder.progress_reporter,
      output,
      total,
      completed1,
      [],
    )

  case builder.progress_reporter {
    None -> Nil
    Some(progress_reporter) ->
      write_progress_event(
        progress_reporter,
        reporter_types.RunFinished(
          completed: completed2,
          total: total,
          results: results,
        ),
        output,
      )
  }

  write_results_reporters(builder.results_reporters, results, output)

  maybe_exit_on_failure(builder.should_exit_on_failure, results)

  results
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
  suites: List(TestSuite(ctx)),
  predicate: Option(fn(TestInfo) -> Bool),
) -> List(TestSuite(ctx)) {
  case predicate {
    None -> suites
    Some(p) -> filter_suites(suites, p, [])
  }
}

fn filter_suites(
  suites: List(TestSuite(ctx)),
  predicate: fn(TestInfo) -> Bool,
  acc_rev: List(TestSuite(ctx)),
) -> List(TestSuite(ctx)) {
  case suites {
    [] -> list.reverse(acc_rev)
    [suite, ..rest] -> {
      let #(maybe, _has_tests) = filter_root(suite, predicate)
      case maybe {
        None -> filter_suites(rest, predicate, acc_rev)
        Some(filtered) -> filter_suites(rest, predicate, [filtered, ..acc_rev])
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
    Test(name: name, tags: tags, kind: kind, run: run, timeout_ms: timeout_ms) -> {
      let full_name = list.append(scope, [name])
      let effective_tags = list.append(inherited_tags, tags)
      let info =
        TestInfo(
          name: name,
          full_name: full_name,
          tags: effective_tags,
          kind: kind,
        )
      case predicate(info) {
        True -> #(
          Some(Test(
            name: name,
            tags: tags,
            kind: kind,
            run: run,
            timeout_ms: timeout_ms,
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

fn run_suites_with_progress(
  suites: List(TestSuite(ctx)),
  config: parallel.ParallelConfig,
  progress_reporter: Option(progress.ProgressReporter),
  output: Output,
  total: Int,
  completed: Int,
  acc: List(TestResult),
) -> #(List(TestResult), Int) {
  case suites {
    [] -> #(acc, completed)
    [suite, ..rest] -> {
      let parallel_result =
        parallel.run_root_parallel_with_reporter(
          parallel.RunRootParallelWithReporterConfig(
            config: config,
            suite: suite,
            progress_reporter: progress_reporter,
            write: output_out(output),
            total: total,
            completed: completed,
          ),
        )
      let parallel.RunRootParallelWithReporterResult(
        results: results,
        completed: completed_after_suite,
        progress_reporter: next_progress_reporter,
      ) = parallel_result

      run_suites_with_progress(
        rest,
        config,
        next_progress_reporter,
        output,
        total,
        completed_after_suite,
        list.append(acc, results),
      )
    }
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

fn count_total_tests(suites: List(TestSuite(ctx))) -> Int {
  count_total_tests_from_list(suites, 0)
}

fn count_total_tests_from_list(suites: List(TestSuite(ctx)), acc: Int) -> Int {
  case suites {
    [] -> acc
    [suite, ..rest] ->
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
