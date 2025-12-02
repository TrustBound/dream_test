/// Parallel test execution with configurable concurrency.
///
/// This module provides concurrent test execution while maintaining
/// deterministic result ordering. Tests run in isolated processes
/// using the sandbox module.
import dream_test/timing
import dream_test/types.{
  type AssertionResult, type SingleTestConfig, type TestCase, type TestResult,
  type TestSuite, type TestSuiteItem, AssertionFailed, AssertionOk,
  AssertionSkipped, Failed, SetupFailed, Skipped, SuiteGroup, SuiteTest,
  TestCase, TestResult, TimedOut,
}
import gleam/erlang/process.{
  type Pid, type Selector, type Subject, kill, monitor, new_selector,
  new_subject, select, selector_receive, send, spawn_unlinked,
}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string

/// Configuration for parallel test execution.
pub type ParallelConfig {
  ParallelConfig(max_concurrency: Int, default_timeout_ms: Int)
}

/// Default parallel configuration: 4 concurrent tests, 5 second timeout.
pub fn default_config() -> ParallelConfig {
  ParallelConfig(max_concurrency: 4, default_timeout_ms: 5000)
}

/// Internal state for tracking parallel execution.
type ExecutionState {
  ExecutionState(
    pending: List(IndexedTest),
    running: List(RunningTest),
    completed: List(IndexedResult),
    results_subject: Subject(WorkerResult),
    config: ParallelConfig,
  )
}

/// A test paired with its original index for ordering.
type IndexedTest {
  IndexedTest(index: Int, test_case: TestCase)
}

/// A running test with its worker info.
type RunningTest {
  RunningTest(
    index: Int,
    test_case: TestCase,
    worker_pid: Pid,
    worker_monitor: process.Monitor,
  )
}

/// A completed result paired with its original index.
type IndexedResult {
  IndexedResult(index: Int, result: TestResult)
}

/// Message from a worker process.
type WorkerResult {
  WorkerCompleted(index: Int, test_run_result: TestRunResult, duration_ms: Int)
  WorkerDown(index: Int, reason: String)
}

/// Run tests in parallel with the given configuration.
///
/// Tests are executed concurrently up to max_concurrency.
/// Results are returned in the same order as the input tests.
pub fn run_parallel(
  config: ParallelConfig,
  test_cases: List(TestCase),
) -> List(TestResult) {
  let indexed_tests = index_tests(test_cases, 0, [])
  let results_subject = new_subject()

  let initial_state =
    ExecutionState(
      pending: indexed_tests,
      running: [],
      completed: [],
      results_subject: results_subject,
      config: config,
    )

  let final_state = execute_loop(initial_state)
  sort_results(final_state.completed)
}

/// Add indices to tests for ordering.
fn index_tests(
  tests: List(TestCase),
  index: Int,
  accumulated: List(IndexedTest),
) -> List(IndexedTest) {
  case tests {
    [] -> list.reverse(accumulated)
    [head, ..tail] -> {
      let indexed = IndexedTest(index: index, test_case: head)
      index_tests(tail, index + 1, [indexed, ..accumulated])
    }
  }
}

/// Main execution loop.
fn execute_loop(state: ExecutionState) -> ExecutionState {
  let state_with_workers = start_workers_up_to_limit(state)

  case is_execution_complete(state_with_workers) {
    True -> state_with_workers
    False -> {
      let updated_state = wait_for_result(state_with_workers)
      execute_loop(updated_state)
    }
  }
}

/// Check if all tests are complete.
fn is_execution_complete(state: ExecutionState) -> Bool {
  list.is_empty(state.pending) && list.is_empty(state.running)
}

/// Start workers up to the concurrency limit.
fn start_workers_up_to_limit(state: ExecutionState) -> ExecutionState {
  let current_running = list.length(state.running)
  let slots_available = state.config.max_concurrency - current_running

  case slots_available > 0 && !list.is_empty(state.pending) {
    False -> state
    True -> {
      let state_with_worker = start_next_worker(state)
      start_workers_up_to_limit(state_with_worker)
    }
  }
}

/// Start the next pending test as a worker.
fn start_next_worker(state: ExecutionState) -> ExecutionState {
  case state.pending {
    [] -> state
    [indexed_test, ..remaining_pending] -> {
      let running_test =
        spawn_test_worker(state.results_subject, indexed_test, state.config)

      ExecutionState(..state, pending: remaining_pending, running: [
        running_test,
        ..state.running
      ])
    }
  }
}

/// Spawn a worker process for a test.
fn spawn_test_worker(
  results_subject: Subject(WorkerResult),
  indexed_test: IndexedTest,
  _config: ParallelConfig,
) -> RunningTest {
  let test_index = indexed_test.index
  let test_case = indexed_test.test_case

  let worker_pid =
    spawn_unlinked(fn() {
      let start_time = timing.now_ms()
      let test_run_result = run_test_directly(test_case)
      let duration_ms = timing.now_ms() - start_time
      send(
        results_subject,
        WorkerCompleted(test_index, test_run_result, duration_ms),
      )
    })

  let worker_monitor = monitor(worker_pid)

  RunningTest(
    index: test_index,
    test_case: test_case,
    worker_pid: worker_pid,
    worker_monitor: worker_monitor,
  )
}

/// Result of running a test with hooks.
/// Tracks whether the failure came from setup, test, or teardown.
type TestRunResult {
  /// Test passed (all hooks and test body passed)
  TestPassed
  /// Test was skipped
  TestSkipped
  /// A before_each hook failed (test was not run)
  SetupFailure(failure: types.AssertionFailure)
  /// The test body failed
  TestFailure(failure: types.AssertionFailure)
  /// An after_each hook failed (test may have passed)
  TeardownFailure(failure: types.AssertionFailure)
}

/// Run a test case directly in the current process.
///
/// Executes lifecycle hooks in the correct order:
/// 1. Run before_each hooks (outer to inner)
/// 2. If all hooks pass, run the test
/// 3. Run after_each hooks (inner to outer), even if test failed
fn run_test_directly(test_case: TestCase) -> TestRunResult {
  case test_case {
    TestCase(config) -> run_with_hooks(config)
  }
}

/// Run a test with its before_each and after_each hooks.
fn run_with_hooks(config: SingleTestConfig) -> TestRunResult {
  // Run before_each hooks
  let before_result = run_hooks(config.before_each_hooks)

  case before_result {
    AssertionFailed(failure) -> SetupFailure(failure)
    // Hooks returning AssertionSkipped are treated as passing
    AssertionOk | AssertionSkipped -> run_test_and_after(config)
  }
}

fn run_test_and_after(config: SingleTestConfig) -> TestRunResult {
  // Run the test
  let test_result = config.run()

  // Always run after_each hooks
  let after_result = run_hooks(config.after_each_hooks)

  // Determine final result
  case test_result, after_result {
    AssertionSkipped, _ -> TestSkipped
    AssertionFailed(failure), _ -> TestFailure(failure)
    AssertionOk, AssertionFailed(failure) -> TeardownFailure(failure)
    // Hooks returning AssertionSkipped are treated as passing
    AssertionOk, AssertionOk -> TestPassed
    AssertionOk, AssertionSkipped -> TestPassed
  }
}

/// Run a list of hooks sequentially, stopping on first failure.
fn run_hooks(hooks: List(fn() -> AssertionResult)) -> AssertionResult {
  run_hooks_from_list(hooks)
}

fn run_hooks_from_list(
  remaining: List(fn() -> AssertionResult),
) -> AssertionResult {
  case remaining {
    [] -> AssertionOk
    [hook, ..rest] -> {
      let result = hook()
      case result {
        // Hooks returning AssertionSkipped are treated as passing
        AssertionOk | AssertionSkipped -> run_hooks_from_list(rest)
        AssertionFailed(_) -> result
      }
    }
  }
}

/// Wait for a result from any running worker.
fn wait_for_result(state: ExecutionState) -> ExecutionState {
  let selector = build_results_selector(state)

  // Wait indefinitely - workers have their own timeouts
  case selector_receive(selector, 60_000) {
    Ok(worker_result) -> handle_worker_result(state, worker_result)
    Error(Nil) -> handle_selector_timeout(state)
  }
}

/// Build a selector for worker results and monitor events.
fn build_results_selector(state: ExecutionState) -> Selector(WorkerResult) {
  new_selector()
  |> select(state.results_subject)
  |> add_monitor_handlers(state.running)
}

/// Add monitor handlers for all running workers.
fn add_monitor_handlers(
  selector: Selector(WorkerResult),
  running: List(RunningTest),
) -> Selector(WorkerResult) {
  case running {
    [] -> selector
    [running_test, ..rest] -> {
      let updated_selector =
        process.select_specific_monitor(
          selector,
          running_test.worker_monitor,
          fn(down) { WorkerDown(running_test.index, format_down_reason(down)) },
        )
      add_monitor_handlers(updated_selector, rest)
    }
  }
}

/// Format a down message reason as a string.
fn format_down_reason(down: process.Down) -> String {
  case down.reason {
    process.Normal -> "normal"
    process.Killed -> "killed"
    process.Abnormal(reason) -> string.inspect(reason)
  }
}

/// Handle a result from a worker.
fn handle_worker_result(
  state: ExecutionState,
  worker_result: WorkerResult,
) -> ExecutionState {
  let index = get_worker_result_index(worker_result)
  let running_test = find_running_test(state.running, index)

  case running_test {
    None -> state
    // Spurious message, ignore
    Some(running) -> {
      let test_result = convert_worker_result(running, worker_result)
      let indexed_result = IndexedResult(index: index, result: test_result)

      ExecutionState(
        ..state,
        running: remove_running_test(state.running, index),
        completed: [indexed_result, ..state.completed],
      )
    }
  }
}

/// Extract the index from a worker result.
fn get_worker_result_index(result: WorkerResult) -> Int {
  case result {
    WorkerCompleted(index, _, _) -> index
    WorkerDown(index, _) -> index
  }
}

/// Find a running test by index.
fn find_running_test(
  running: List(RunningTest),
  index: Int,
) -> Option(RunningTest) {
  case running {
    [] -> None
    [running_test, ..rest] -> find_running_test_check(running_test, rest, index)
  }
}

fn find_running_test_check(
  running_test: RunningTest,
  rest: List(RunningTest),
  index: Int,
) -> Option(RunningTest) {
  case running_test.index == index {
    True -> Some(running_test)
    False -> find_running_test(rest, index)
  }
}

/// Remove a running test by index.
fn remove_running_test(
  running: List(RunningTest),
  index: Int,
) -> List(RunningTest) {
  list.filter(running, fn(running_test) { running_test.index != index })
}

/// Convert a worker result to a TestResult.
fn convert_worker_result(
  running_test: RunningTest,
  worker_result: WorkerResult,
) -> TestResult {
  case running_test.test_case {
    TestCase(config) -> convert_worker_result_with_config(config, worker_result)
  }
}

fn convert_worker_result_with_config(
  config: SingleTestConfig,
  worker_result: WorkerResult,
) -> TestResult {
  case worker_result {
    WorkerCompleted(_, test_run_result, duration_ms) ->
      test_run_result_to_test_result(config, test_run_result, duration_ms)
    WorkerDown(_, reason) -> make_crashed_result(config, reason, 0)
  }
}

/// Convert a TestRunResult to a TestResult.
fn test_run_result_to_test_result(
  config: SingleTestConfig,
  test_run_result: TestRunResult,
  duration_ms: Int,
) -> TestResult {
  case test_run_result {
    TestPassed -> make_passed_result(config, duration_ms)
    TestSkipped -> make_skipped_result(config, duration_ms)
    SetupFailure(failure) ->
      make_setup_failed_result(config, failure, duration_ms)
    TestFailure(failure) -> make_failed_result(config, failure, duration_ms)
    TeardownFailure(failure) -> make_failed_result(config, failure, duration_ms)
  }
}

fn make_passed_result(config: SingleTestConfig, duration_ms: Int) -> TestResult {
  TestResult(
    name: config.name,
    full_name: config.full_name,
    status: types.Passed,
    duration_ms: duration_ms,
    tags: config.tags,
    failures: [],
    kind: config.kind,
  )
}

fn make_skipped_result(config: SingleTestConfig, duration_ms: Int) -> TestResult {
  TestResult(
    name: config.name,
    full_name: config.full_name,
    status: Skipped,
    duration_ms: duration_ms,
    tags: config.tags,
    failures: [],
    kind: config.kind,
  )
}

fn make_setup_failed_result(
  config: SingleTestConfig,
  failure: types.AssertionFailure,
  duration_ms: Int,
) -> TestResult {
  TestResult(
    name: config.name,
    full_name: config.full_name,
    status: SetupFailed,
    duration_ms: duration_ms,
    tags: config.tags,
    failures: [failure],
    kind: config.kind,
  )
}

fn make_failed_result(
  config: SingleTestConfig,
  failure: types.AssertionFailure,
  duration_ms: Int,
) -> TestResult {
  TestResult(
    name: config.name,
    full_name: config.full_name,
    status: Failed,
    duration_ms: duration_ms,
    tags: config.tags,
    failures: [failure],
    kind: config.kind,
  )
}

/// Create a TestResult for a timed-out test.
fn make_timeout_result(config: SingleTestConfig, duration_ms: Int) -> TestResult {
  TestResult(
    name: config.name,
    full_name: config.full_name,
    status: TimedOut,
    duration_ms: duration_ms,
    tags: config.tags,
    failures: [],
    kind: config.kind,
  )
}

/// Create a TestResult for a crashed test.
fn make_crashed_result(
  config: SingleTestConfig,
  reason: String,
  duration_ms: Int,
) -> TestResult {
  let failure =
    types.AssertionFailure(
      operator: "crash",
      message: "Test process crashed: " <> reason,
      payload: None,
    )

  TestResult(
    name: config.name,
    full_name: config.full_name,
    status: Failed,
    duration_ms: duration_ms,
    tags: config.tags,
    failures: [failure],
    kind: config.kind,
  )
}

/// Handle selector timeout (should not happen in normal operation).
fn handle_selector_timeout(state: ExecutionState) -> ExecutionState {
  // Kill all running workers and mark them as timed out
  kill_all_running(state.running)

  let timeout_results =
    list.map(state.running, fn(running_test) {
      case running_test.test_case {
        TestCase(config) -> {
          // Use the configured timeout as the duration for timed-out tests
          IndexedResult(
            index: running_test.index,
            result: make_timeout_result(config, state.config.default_timeout_ms),
          )
        }
      }
    })

  ExecutionState(
    ..state,
    running: [],
    completed: list.append(timeout_results, state.completed),
  )
}

/// Kill all running worker processes.
fn kill_all_running(running: List(RunningTest)) -> Nil {
  case running {
    [] -> Nil
    [running_test, ..rest] -> {
      kill(running_test.worker_pid)
      kill_all_running(rest)
    }
  }
}

/// Sort completed results by their original index.
fn sort_results(completed: List(IndexedResult)) -> List(TestResult) {
  completed
  |> list.sort(fn(a, b) { compare_indices(a.index, b.index) })
  |> list.map(fn(indexed) { indexed.result })
}

/// Compare two indices for sorting.
fn compare_indices(a: Int, b: Int) -> order.Order {
  case a < b {
    True -> order.Lt
    False -> compare_indices_not_less(a, b)
  }
}

fn compare_indices_not_less(a: Int, b: Int) -> order.Order {
  case a > b {
    True -> order.Gt
    False -> order.Eq
  }
}

// =============================================================================
// Suite Execution (with before_all/after_all support)
// =============================================================================

/// Run a test suite with before_all/after_all semantics.
///
/// Execution flow for each group:
/// 1. Run before_all hooks sequentially
/// 2. If any fail, mark all tests in group as SetupFailed
/// 3. Run tests in parallel (with their before_each/after_each)
/// 4. Wait for all tests to complete
/// 5. Run after_all hooks sequentially
/// 6. Recurse for nested groups
///
pub fn run_suite_parallel(
  config: ParallelConfig,
  suite: TestSuite,
) -> List(TestResult) {
  run_suite_group(config, suite)
}

fn run_suite_group(config: ParallelConfig, suite: TestSuite) -> List(TestResult) {
  // Run before_all hooks
  let before_all_result = run_hooks(suite.before_all_hooks)

  case before_all_result {
    AssertionFailed(failure) ->
      mark_all_items_as_setup_failed(suite.items, failure)
    // Hooks returning AssertionSkipped are treated as passing
    AssertionOk | AssertionSkipped -> {
      // Run all items (tests and nested groups)
      let results = run_suite_items(config, suite.items)

      // Run after_all hooks (regardless of test results)
      let _after_all_result = run_hooks(suite.after_all_hooks)

      // Return results (after_all failures don't change test results)
      results
    }
  }
}

fn mark_all_items_as_setup_failed(
  items: List(TestSuiteItem),
  failure: types.AssertionFailure,
) -> List(TestResult) {
  mark_items_failed_from_list(items, failure, [])
}

fn mark_items_failed_from_list(
  remaining: List(TestSuiteItem),
  failure: types.AssertionFailure,
  accumulated: List(TestResult),
) -> List(TestResult) {
  case remaining {
    [] -> list.reverse(accumulated)
    [item, ..rest] -> {
      let results = mark_item_as_setup_failed(item, failure)
      let updated = list.append(list.reverse(results), accumulated)
      mark_items_failed_from_list(rest, failure, updated)
    }
  }
}

fn mark_item_as_setup_failed(
  item: TestSuiteItem,
  failure: types.AssertionFailure,
) -> List(TestResult) {
  case item {
    SuiteTest(test_case) -> {
      let TestCase(config) = test_case
      // Duration is 0 for setup failures since the test never ran
      [make_setup_failed_result(config, failure, 0)]
    }
    SuiteGroup(nested_suite) ->
      mark_all_items_as_setup_failed(nested_suite.items, failure)
  }
}

fn run_suite_items(
  config: ParallelConfig,
  items: List(TestSuiteItem),
) -> List(TestResult) {
  // Separate tests from nested groups
  let tests = collect_tests_from_items(items, [])
  let groups = collect_groups_from_items(items, [])

  // Run tests in parallel
  let test_results = run_parallel(config, tests)

  // Run nested groups (each group runs its before_all/after_all)
  let group_results = run_groups_sequentially(config, groups, [])

  // Combine results (tests first, then groups, preserving order)
  list.append(test_results, group_results)
}

fn collect_tests_from_items(
  remaining: List(TestSuiteItem),
  accumulated: List(TestCase),
) -> List(TestCase) {
  case remaining {
    [] -> list.reverse(accumulated)
    [item, ..rest] -> {
      let updated = case item {
        SuiteTest(test_case) -> [test_case, ..accumulated]
        SuiteGroup(_) -> accumulated
      }
      collect_tests_from_items(rest, updated)
    }
  }
}

fn collect_groups_from_items(
  remaining: List(TestSuiteItem),
  accumulated: List(TestSuite),
) -> List(TestSuite) {
  case remaining {
    [] -> list.reverse(accumulated)
    [item, ..rest] -> {
      let updated = case item {
        SuiteTest(_) -> accumulated
        SuiteGroup(suite) -> [suite, ..accumulated]
      }
      collect_groups_from_items(rest, updated)
    }
  }
}

fn run_groups_sequentially(
  config: ParallelConfig,
  remaining: List(TestSuite),
  accumulated: List(TestResult),
) -> List(TestResult) {
  case remaining {
    [] -> list.reverse(accumulated)
    [suite, ..rest] -> {
      let results = run_suite_group(config, suite)
      let updated = list.append(list.reverse(results), accumulated)
      run_groups_sequentially(config, rest, updated)
    }
  }
}
