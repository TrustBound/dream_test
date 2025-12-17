//// Test runner for dream_test (suite-first).
////
//// This module provides a pipe-friendly builder API for running suites.
////
//// ```gleam
//// import dream_test/runner
//// import dream_test/reporter/api as reporter
//// import dream_test/unit.{describe, it}
//// import dream_test/types.{AssertionOk}
//// import gleam/io
////
//// let suite =
////   describe("Example", [
////     it("passes", fn(_) { Ok(AssertionOk) }),
////   ])
////
//// runner.new([suite])
//// |> runner.reporter(reporter.bdd(io.print, True))
//// |> runner.max_concurrency(8)
//// |> runner.default_timeout_ms(10_000)
//// |> runner.exit_on_failure()
//// |> runner.run()
//// ```

import dream_test/parallel
import dream_test/reporter/api as reporter_api
import dream_test/reporter/types as reporter_types
import dream_test/types.{
  type AssertionFailure, type Status, type SuiteTestCase, type TestResult,
  type TestSuite, type TestSuiteItem, Failed, Passed, SetupFailed, SuiteGroup,
  SuiteTest, TestResult, TimedOut,
}
import gleam/list
import gleam/option.{type Option, None, Some}

/// Builder-style runner configuration.
///
/// The type parameter `ctx` is the suite context type shared by hooks/tests in
/// your `TestSuite(ctx)`. For plain unit tests built with `unit.describe`, that
/// context is `Nil`.
///
/// You generally don’t construct `RunBuilder` directly—use `runner.new(...)` and
/// then apply builder functions like `max_concurrency`, `reporter`, and
/// `exit_on_failure`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/reporter/api as reporter
/// import dream_test/runner
/// import gleam/io
///
/// runner.new([suite])
/// |> runner.reporter(reporter.bdd(io.print, True))
/// |> runner.max_concurrency(4)
/// |> runner.exit_on_failure()
/// |> runner.run()
/// ```
pub opaque type RunBuilder(ctx) {
  RunBuilder(
    suites: List(TestSuite(ctx)),
    config: parallel.ParallelConfig,
    result_filter: Option(fn(TestResult) -> Bool),
    should_exit_on_failure: Bool,
    reporter: Option(reporter_api.Reporter),
  )
}

/// Start building a test run.
///
/// The returned builder starts with:
///
/// - no reporter (no output)
/// - no result filter
/// - `exit_on_failure` disabled
/// - parallel defaults from `parallel.default_config()` (currently:
///   max concurrency 4, default timeout 5000ms)
///
/// ## Example
///
/// ```gleam
/// import dream_test/runner
/// import dream_test/unit.{describe, it}
/// import dream_test/types.{AssertionOk}
///
/// let suite =
///   describe("Example", [
///     it("passes", fn(_) { Ok(AssertionOk) }),
///   ])
///
/// let builder = runner.new([suite])
/// ```
///
/// ## Parameters
///
/// - `suites`: root suites to run
///
/// ## Returns
///
/// A `RunBuilder(ctx)` you can further configure.
pub fn new(suites: List(TestSuite(ctx))) -> RunBuilder(ctx) {
  RunBuilder(
    suites: suites,
    config: parallel.default_config(),
    result_filter: None,
    should_exit_on_failure: False,
    reporter: None,
  )
}

/// Set the maximum number of tests to execute concurrently.
///
/// This does not change result ordering; results are still returned in
/// deterministic traversal order.
///
/// ## Example
///
/// ```gleam
/// runner.new([suite])
/// |> runner.max_concurrency(8)
/// |> runner.run()
/// ```
///
/// ## Parameters
///
/// - `builder`: the current `RunBuilder`
/// - `max`: maximum number of concurrent tests (>= 1)
///
/// ## Returns
///
/// A new `RunBuilder` with updated concurrency.
pub fn max_concurrency(builder: RunBuilder(ctx), max: Int) -> RunBuilder(ctx) {
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

/// Set the default per-test timeout in milliseconds.
///
/// This timeout is used when a test does not specify its own `timeout_ms`.
///
/// ## Example
///
/// ```gleam
/// runner.new([suite])
/// |> runner.default_timeout_ms(10_000)
/// |> runner.run()
/// ```
///
/// ## Parameters
///
/// - `builder`: the current `RunBuilder`
/// - `timeout_ms`: timeout to apply when a test does not specify its own timeout
///
/// ## Returns
///
/// A new `RunBuilder` with updated default timeout.
pub fn default_timeout_ms(
  builder: RunBuilder(ctx),
  timeout_ms: Int,
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

/// Configure the runner to exit non-zero if any test fails.
///
/// Exits after `run()` completes.
///
/// If a `filter_results(...)` predicate is present, the exit decision is based
/// on the **filtered** results.
///
/// ## Example
///
/// ```gleam
/// runner.new([suite])
/// |> runner.exit_on_failure()
/// |> runner.run()
/// ```
///
/// ## Returns
///
/// A new `RunBuilder` with exit-on-failure enabled.
pub fn exit_on_failure(builder: RunBuilder(ctx)) -> RunBuilder(ctx) {
  RunBuilder(..builder, should_exit_on_failure: True)
}

/// Attach an event-driven reporter.
///
/// When present, the runner will drive the reporter with `ReporterEvent`s and
/// the reporter will print output (including progress) during the run.
///
/// ## Parameters
///
/// - `builder`: the current `RunBuilder`
/// - `reporter`: a reporter created via `dream_test/reporter/api`
///
/// ## Returns
///
/// A new `RunBuilder` with the reporter attached.
///
/// ## Example
///
/// ```gleam
/// import dream_test/reporter/api as reporter
/// import gleam/io
///
/// runner.new([suite])
/// |> runner.reporter(reporter.bdd(io.print, True))
/// |> runner.run()
/// ```
pub fn reporter(
  builder: RunBuilder(ctx),
  reporter: reporter_api.Reporter,
) -> RunBuilder(ctx) {
  RunBuilder(..builder, reporter: Some(reporter))
}

/// Filter the returned results list (and any exit-on-failure decision) by a predicate.
///
/// This is commonly used for tag filtering in CI.
///
/// ## Example
///
/// ```gleam
/// import dream_test/types.{type TestResult}
/// import gleam/list
///
/// fn is_smoke(result: TestResult) {
///   list.contains(result.tags, "smoke")
/// }
///
/// runner.new([suite])
/// |> runner.filter_results(is_smoke)
/// |> runner.run()
/// ```
///
/// ## Parameters
///
/// - `builder`: the current `RunBuilder`
/// - `predicate`: keep results where this returns `True`
///
/// ## Returns
///
/// A new `RunBuilder` with the filter installed.
pub fn filter_results(
  builder: RunBuilder(ctx),
  predicate: fn(TestResult) -> Bool,
) -> RunBuilder(ctx) {
  RunBuilder(..builder, result_filter: Some(predicate))
}

/// Execute all suites and return the combined results.
///
/// If `exit_on_failure()` was set, this function terminates the process (via
/// `erlang:halt/1`) after running.
///
/// ## after_all failure behavior
///
/// If any suite’s `after_all` fails, the runner stops executing subsequent root
/// suites. Tests in those later suites are returned as `SetupFailed` with a
/// failure message derived from the `after_all` failure.
///
/// ## Example
///
/// ```gleam
/// let results = runner.new([suite]) |> runner.run()
/// ```
///
/// ## Returns
///
/// A list of `TestResult` values (one per test), in deterministic traversal order.
pub fn run(builder: RunBuilder(ctx)) -> List(TestResult) {
  let results0 = case builder.reporter {
    None -> run_suites(builder.config, builder.suites, [])
    Some(reporter) ->
      run_suites_with_reporter(builder.config, builder.suites, reporter)
  }

  let results = case builder.result_filter {
    None -> results0
    Some(predicate) -> list.filter(results0, predicate)
  }

  case builder.should_exit_on_failure {
    True -> halt_with_results_on_failure(results)
    False -> results
  }
}

fn run_suites(
  config: parallel.ParallelConfig,
  suites: List(TestSuite(ctx)),
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case suites {
    [] -> list.reverse(acc_rev)
    [suite, ..rest] -> {
      let suite_results = parallel.run_suite_parallel(config, suite)
      let next_acc_rev = push_results_rev(suite_results, acc_rev)

      case find_after_all_failure_message(suite_results) {
        None -> run_suites(config, rest, next_acc_rev)
        Some(message) -> {
          let remaining = suites_to_setup_failed_results(rest, message, [])
          list.reverse(push_results_rev(remaining, next_acc_rev))
        }
      }
    }
  }
}

fn run_suites_with_reporter(
  config: parallel.ParallelConfig,
  suites: List(TestSuite(ctx)),
  reporter0: reporter_api.Reporter,
) -> List(TestResult) {
  let total = count_tests_in_suites(suites, 0)
  let reporter1 =
    reporter_api.handle_event(reporter0, reporter_types.RunStarted(total))

  let #(results_rev, completed, reporter_final) =
    run_suites_with_reporter_loop(config, suites, reporter1, total, 0, [])

  let _ =
    reporter_api.handle_event(
      reporter_final,
      reporter_types.RunFinished(completed, total),
    )

  list.reverse(results_rev)
}

fn run_suites_with_reporter_loop(
  config: parallel.ParallelConfig,
  suites: List(TestSuite(ctx)),
  reporter: reporter_api.Reporter,
  total: Int,
  completed: Int,
  acc_rev: List(TestResult),
) -> #(List(TestResult), Int, reporter_api.Reporter) {
  case suites {
    [] -> #(acc_rev, completed, reporter)
    [suite, ..rest] -> {
      let #(suite_results, next_completed, next_reporter) =
        parallel.run_suite_parallel_with_reporter(
          config,
          suite,
          reporter,
          total,
          completed,
        )
      let next_acc_rev = push_results_rev(suite_results, acc_rev)

      case find_after_all_failure_message(suite_results) {
        None ->
          run_suites_with_reporter_loop(
            config,
            rest,
            next_reporter,
            total,
            next_completed,
            next_acc_rev,
          )

        Some(message) -> {
          let remaining_results =
            suites_to_setup_failed_results(rest, message, [])
          let #(final_completed, final_reporter) =
            emit_test_finished_events(
              remaining_results,
              next_completed,
              total,
              next_reporter,
            )

          let final_acc_rev = push_results_rev(remaining_results, next_acc_rev)
          #(final_acc_rev, final_completed, final_reporter)
        }
      }
    }
  }
}

fn emit_test_finished_events(
  results: List(TestResult),
  completed: Int,
  total: Int,
  reporter: reporter_api.Reporter,
) -> #(Int, reporter_api.Reporter) {
  case results {
    [] -> #(completed, reporter)
    [result, ..rest] -> {
      case result.name == "<after_all>" {
        True -> emit_test_finished_events(rest, completed, total, reporter)
        False -> {
          let next_completed = completed + 1
          let next_reporter =
            reporter_api.handle_event(
              reporter,
              reporter_types.TestFinished(next_completed, total, result),
            )
          emit_test_finished_events(rest, next_completed, total, next_reporter)
        }
      }
    }
  }
}

fn count_tests_in_suites(suites: List(TestSuite(ctx)), acc: Int) -> Int {
  case suites {
    [] -> acc
    [suite, ..rest] ->
      count_tests_in_suites(rest, acc + count_tests_in_suite(suite, 0))
  }
}

fn count_tests_in_suite(suite: TestSuite(ctx), acc: Int) -> Int {
  count_tests_in_items(suite.items, acc)
}

fn count_tests_in_items(items: List(TestSuiteItem(ctx)), acc: Int) -> Int {
  case items {
    [] -> acc
    [item, ..rest] ->
      case item {
        SuiteTest(_) -> count_tests_in_items(rest, acc + 1)
        SuiteGroup(group_suite) ->
          count_tests_in_items(rest, count_tests_in_suite(group_suite, acc))
      }
  }
}

fn push_results_rev(
  results: List(TestResult),
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case results {
    [] -> acc_rev
    [result, ..rest] -> push_results_rev(rest, [result, ..acc_rev])
  }
}

fn find_after_all_failure_message(results: List(TestResult)) -> Option(String) {
  case results {
    [] -> None
    [result, ..rest] -> {
      case result.name == "<after_all>" && result.status == Failed {
        True -> Some(extract_failure_message(result.failures))
        False -> find_after_all_failure_message(rest)
      }
    }
  }
}

fn extract_failure_message(failures: List(AssertionFailure)) -> String {
  case failures {
    [failure, ..] -> failure.message
    [] -> "after_all failed"
  }
}

fn suites_to_setup_failed_results(
  suites: List(TestSuite(ctx)),
  message: String,
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case suites {
    [] -> list.reverse(acc_rev)
    [suite, ..rest] -> {
      let suite_results = suite_to_setup_failed_results(suite, message, [])
      let next_acc_rev = push_results_rev(suite_results, acc_rev)
      suites_to_setup_failed_results(rest, message, next_acc_rev)
    }
  }
}

fn suite_to_setup_failed_results(
  suite: TestSuite(ctx),
  message: String,
  prefix: List(String),
) -> List(TestResult) {
  let suite_prefix = list.append(prefix, [suite.name])
  suite_items_to_setup_failed_results(suite.items, suite_prefix, message, [])
}

fn suite_items_to_setup_failed_results(
  items: List(TestSuiteItem(ctx)),
  prefix: List(String),
  message: String,
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case items {
    [] -> list.reverse(acc_rev)
    [item, ..rest] ->
      case item {
        SuiteTest(test_case) -> {
          let result =
            test_case_to_setup_failed_result(test_case, prefix, message)
          suite_items_to_setup_failed_results(rest, prefix, message, [
            result,
            ..acc_rev
          ])
        }

        SuiteGroup(group_suite) -> {
          let group_results =
            suite_to_setup_failed_results(group_suite, message, prefix)
          let next_acc_rev = push_results_rev(group_results, acc_rev)
          suite_items_to_setup_failed_results(
            rest,
            prefix,
            message,
            next_acc_rev,
          )
        }
      }
  }
}

fn test_case_to_setup_failed_result(
  test_case: SuiteTestCase(ctx),
  prefix: List(String),
  message: String,
) -> TestResult {
  TestResult(
    name: test_case.name,
    full_name: list.append(prefix, [test_case.name]),
    status: SetupFailed,
    duration_ms: 0,
    tags: test_case.tags,
    failures: [
      types.AssertionFailure(
        operator: "after_all",
        message: message,
        payload: None,
      ),
    ],
    kind: test_case.kind,
  )
}

fn halt_with_results_on_failure(results: List(TestResult)) -> List(TestResult) {
  let code = case has_failures(results) {
    True -> 1
    False -> 0
  }
  halt(code)
}

/// Check if any test results indicate failure.
///
/// This returns `True` if **any** result has a failure status:
///
/// - `Failed`
/// - `TimedOut`
/// - `SetupFailed`
///
/// (Other statuses like `Passed` and `Skipped` do not count as failures.)
///
/// ## Example
///
/// ```gleam
/// let failed = runner.has_failures(results)
/// ```
pub fn has_failures(results: List(TestResult)) -> Bool {
  case results {
    [] -> False
    [result, ..rest] -> check_status(result.status, rest)
  }
}

fn check_status(status: Status, rest: List(TestResult)) -> Bool {
  case status {
    Failed -> True
    TimedOut -> True
    SetupFailed -> True
    Passed -> has_failures(rest)
    _ -> has_failures(rest)
  }
}

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> List(TestResult)
