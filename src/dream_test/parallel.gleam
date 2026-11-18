//// Unified Root/Node execution engine (parallel tests, sequential groups).
////
//// This module executes `types.TestSuite(context)` which is an alias of
//// `types.Root(context)` in the unified tree model.
////
//// NOTE: This module is intentionally event-agnostic; `runner` composes it
//// with reporters for live output.
////
//// Most users should not call this module directly—prefer `dream_test/runner`.
//// This module is public so advanced users can embed the executor in other
//// tooling (custom runners, IDE integrations, etc.).
////
//// ## Example
////
//// ```gleam
//// import dream_test/matchers.{have_length, or_fail_with, should, succeed}
//// import dream_test/parallel
//// import dream_test/types
//// import dream_test/unit.{describe, it}
////
//// pub fn tests() {
////   describe("Parallel executor", [
////     it("can run a suite and return a report of the results", fn() {
////       let suite =
////         describe("Suite", [
////           it("a", fn() { Ok(succeed()) }),
////           it("b", fn() { Ok(succeed()) }),
////         ])
////
////       parallel.run_root_parallel(parallel.default_config(), suite)
////       |> types.report_tests
////       |> should
////       |> have_length(2)
////       |> or_fail_with("expected two results")
////     }),
////   ])
//// }
//// ```

import dream_test/reporters/progress
import dream_test/sandbox
import dream_test/timing
import dream_test/types.{
  type AssertionFailure, type AssertionResult, type Callback, type Node,
  type RunReport, type Status, type TeardownFailure, type TeardownHook,
  type TestInfo, type TestKind, type TestResult, type TestSuite, AfterAll,
  AfterAllHook, AfterEach, AfterEachHook, AfterEachTestHook, AssertionFailed,
  AssertionFailure, AssertionOk, AssertionSkipped, BeforeAll, BeforeEach, Failed,
  Group, Passed, Root, SetupFailed, Skipped, TeardownFailure, Test, TestResult,
  TimedOut,
}
import gleam/erlang/process.{
  type Down, type Monitor, type Pid, type Selector, type Subject,
  demonitor_process, monitor, new_selector, new_subject, select,
  select_specific_monitor, selector_receive_forever, send, spawn_unlinked,
}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// Configuration for the parallel executor.
///
/// Most users should configure execution via `dream_test/runner` instead of
/// calling `dream_test/parallel` directly.
///
/// - `max_concurrency`: how many tests may run at once
/// - `default_timeout_ms`: default per-test timeout (used when a test doesn’t
///   specify its own timeout)
///
/// ## Fields
///
/// - `max_concurrency`: maximum number of tests to run concurrently within a group
/// - `default_timeout_ms`: timeout used when a test does not set its own timeout
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{have_length, or_fail_with, should, succeed}
/// import dream_test/parallel.{ParallelConfig}
/// import dream_test/unit.{describe, it}
///
/// pub fn tests() {
///   let config = ParallelConfig(max_concurrency: 2, default_timeout_ms: 1000)
///
///   describe("ParallelConfig", [
///     it("can be constructed to customize execution", fn() {
///       let suite =
///         describe("Suite", [
///           it("a", fn() { Ok(succeed()) }),
///         ])
///
///       parallel.run_root_parallel(config, suite)
///       |> should
///       |> have_length(1)
///       |> or_fail_with("expected one result")
///     }),
///   ])
/// }
/// ```
pub type ParallelConfig {
  ParallelConfig(max_concurrency: Int, default_timeout_ms: Int)
}

/// Configuration for `run_root_parallel_with_reporter`.
///
/// This is an advanced API intended for building custom runners that want to
/// drive a reporter while executing a single suite.
pub type RunRootParallelWithReporterConfig(context) {
  RunRootParallelWithReporterConfig(
    config: ParallelConfig,
    suite: TestSuite(context),
    progress_reporter: Option(progress.ProgressReporter),
    write: fn(String) -> Nil,
    total: Int,
    completed: Int,
    runner_before_each_test: List(
      fn(TestInfo, context) -> Result(context, String),
    ),
    runner_after_each_test: List(fn(TestInfo, context) -> Result(Nil, String)),
  )
}

/// Result of `run_root_parallel_with_reporter`.
///
/// This is returned as a semantic type (not a tuple) so callers can use named
/// fields and avoid positional destructuring. A tear-down failure is not a
/// test result, so it is in `teardown_failures`, not in `results`.
pub type RunRootParallelWithReporterResult {
  RunRootParallelWithReporterResult(
    results: List(TestResult),
    teardown_failures: List(TeardownFailure),
    completed: Int,
    progress_reporter: Option(progress.ProgressReporter),
  )
}

type ExecuteNodeConfig(context) {
  ExecuteNodeConfig(
    config: ParallelConfig,
    scope: List(String),
    inherited_tags: List(String),
    context: context,
    inherited_before_each: List(Callback(context, Result(context, String))),
    inherited_after_each: List(Callback(context, Result(Nil, String))),
    runner_before_each_test: List(
      fn(TestInfo, context) -> Result(context, String),
    ),
    runner_after_each_test: List(fn(TestInfo, context) -> Result(Nil, String)),
    node: Node(context),
    progress_output: Option(ProgressOutput),
    total: Int,
    completed: Int,
    collected: Collected,
  )
}

/// What a run has collected so far, newest first: the test results and the
/// tear-down failures.
type Collected {
  Collected(
    results_rev: List(TestResult),
    teardown_failures_rev: List(TeardownFailure),
  )
}

/// What one test gives: its result, and the `after_each` and
/// `after_each_test` hooks that failed after it, in the order that they ran.
type TestOutcome {
  TestOutcome(result: TestResult, teardown_failures: List(TeardownFailure))
}

/// Where the progress lines of a run go: the progress reporter, and the
/// function that writes its text.
type ProgressOutput {
  ProgressOutput(reporter: progress.ProgressReporter, write: fn(String) -> Nil)
}

/// The progress output of a run that has a progress reporter.
fn progress_output(
  progress_reporter: Option(progress.ProgressReporter),
  write: fn(String) -> Nil,
) -> Option(ProgressOutput) {
  case progress_reporter {
    Some(reporter) -> Some(ProgressOutput(reporter: reporter, write: write))
    None -> None
  }
}

type IndexedResult {
  IndexedResult(index: Int, outcome: TestOutcome)
}

/// A worker that the loop started and that has not given a result yet. The
/// loop monitors it, so a worker that exits before it sends its result
/// still gives a result.
type RunningWorker(context) {
  RunningWorker(monitor: Monitor, index: Int, test_case: TestCase(context))
}

/// One test of a group, taken from its `Test` node.
type TestCase(context) {
  TestCase(
    name: String,
    tags: List(String),
    kind: TestKind,
    run: Callback(context, Result(AssertionResult, String)),
    timeout_ms: Option(Int),
    source: Option(String),
  )
}

type RunParallelLoopConfig(context) {
  RunParallelLoopConfig(
    config: ParallelConfig,
    subject: Subject(WorkerMessage),
    scope: List(String),
    inherited_tags: List(String),
    context: context,
    runner_before_each_test: List(
      fn(TestInfo, context) -> Result(context, String),
    ),
    runner_after_each_test: List(fn(TestInfo, context) -> Result(Nil, String)),
    before_each_hooks: List(Callback(context, Result(context, String))),
    after_each_hooks: List(Callback(context, Result(Nil, String))),
    failures_rev: List(AssertionFailure),
    pending: List(#(Int, TestCase(context))),
    running: List(RunningWorker(context)),
    pending_emit: List(IndexedResult),
    emitted_rev: List(TestOutcome),
    next_emit_index: Int,
    progress_output: Option(ProgressOutput),
    total: Int,
    completed: Int,
    max_concurrency: Int,
  )
}

type StartWorkersUpToLimitConfig(context) {
  StartWorkersUpToLimitConfig(
    config: ParallelConfig,
    subject: Subject(WorkerMessage),
    scope: List(String),
    inherited_tags: List(String),
    context: context,
    runner_before_each_test: List(
      fn(TestInfo, context) -> Result(context, String),
    ),
    runner_after_each_test: List(fn(TestInfo, context) -> Result(Nil, String)),
    before_each_hooks: List(Callback(context, Result(context, String))),
    after_each_hooks: List(Callback(context, Result(Nil, String))),
    failures_rev: List(AssertionFailure),
    pending: List(#(Int, TestCase(context))),
    running: List(RunningWorker(context)),
    max_concurrency: Int,
  )
}

type WaitForResultConfig(context) {
  WaitForResultConfig(
    subject: Subject(WorkerMessage),
    scope: List(String),
    inherited_tags: List(String),
    running: List(RunningWorker(context)),
    pending_emit: List(IndexedResult),
    progress_output: Option(ProgressOutput),
    total: Int,
    completed: Int,
  )
}

/// A message to the loop about one worker. A worker sends `WorkerFinished`
/// when its test finished; a test that timed out or crashed has a result
/// too. `WorkerDown` comes from the monitor of a worker, for a worker that
/// exited before it sent its result, for example when a process outside
/// dream_test killed it.
type WorkerMessage {
  WorkerFinished(index: Int, outcome: TestOutcome)
  WorkerDown(down: Down)
}

/// Default executor configuration.
///
/// Prefer configuring these values via `dream_test/runner` unless you are using
/// the executor directly.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{have_length, or_fail_with, should, succeed}
/// import dream_test/parallel
/// import dream_test/types
/// import dream_test/unit.{describe, it}
///
/// pub fn tests() {
///   describe("Parallel executor", [
///     it("can run a suite and return a report of the results", fn() {
///       let suite =
///         describe("Suite", [
///           it("a", fn() { Ok(succeed()) }),
///           it("b", fn() { Ok(succeed()) }),
///         ])
///
///       parallel.run_root_parallel(parallel.default_config(), suite)
///       |> types.report_tests
///       |> should
///       |> have_length(2)
///       |> or_fail_with("expected two results")
///     }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// None.
///
/// ## Returns
///
/// A `ParallelConfig` with sensible defaults.
pub fn default_config() -> ParallelConfig {
  ParallelConfig(max_concurrency: 4, default_timeout_ms: 5000)
}

/// Run a single suite and return results.
///
/// This does **not** drive a reporter.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{have_length, or_fail_with, should, succeed}
/// import dream_test/parallel
/// import dream_test/types
/// import dream_test/unit.{describe, it}
///
/// pub fn tests() {
///   describe("Parallel executor", [
///     it("can run a suite and return a report of the results", fn() {
///       let suite =
///         describe("Suite", [
///           it("a", fn() { Ok(succeed()) }),
///           it("b", fn() { Ok(succeed()) }),
///         ])
///
///       parallel.run_root_parallel(parallel.default_config(), suite)
///       |> types.report_tests
///       |> should
///       |> have_length(2)
///       |> or_fail_with("expected two results")
///     }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `config`: execution settings (concurrency + default timeout)
/// - `suite`: the suite to execute
///
/// ## Returns
///
/// A `types.RunReport` with the `TestResult` of each test, in deterministic
/// (declaration) order, and the `after_each` and `after_all` hooks that
/// failed, in the order that they ran.
pub fn run_root_parallel(
  config config: ParallelConfig,
  suite suite: TestSuite(context),
) -> RunReport {
  let Root(seed: seed, name: name, tags: tags, children: children) = suite
  let executor_input =
    ExecuteNodeConfig(
      config: config,
      scope: [],
      inherited_tags: [],
      context: seed,
      inherited_before_each: [],
      inherited_after_each: [],
      runner_before_each_test: [],
      runner_after_each_test: [],
      node: Group(name: name, tags: tags, children: children),
      progress_output: None,
      total: 0,
      completed: 0,
      collected: empty_collected(),
    )

  let #(collected, _completed) = execute_node(executor_input)
  types.run_report(
    tests: list.reverse(collected.results_rev),
    teardown_failures: list.reverse(collected.teardown_failures_rev),
  )
}

/// Run a single suite while driving a reporter.
///
/// This is used by `dream_test/runner` internally.
///
/// - `total` is the total number of tests across all suites in the run
/// - `completed` is how many tests have already completed before this suite
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{succeed}
/// import dream_test/parallel
/// import dream_test/types.{type TestSuite}
/// import dream_test/unit.{describe, it}
/// import gleam/option.{None}
/// 
/// pub fn suite() -> TestSuite(Nil) {
///   describe("suite", [
///     it("passes", fn() { Ok(succeed()) }),
///   ])
/// }
/// 
/// fn ignore(_text: String) {
///   Nil
/// }
/// 
/// pub fn main() {
///   let total = 1
///   let completed = 0
///   let parallel_result =
///     parallel.run_root_parallel_with_reporter(
///       parallel.RunRootParallelWithReporterConfig(
///         config: parallel.default_config(),
///         suite: suite(),
///         progress_reporter: None,
///         write: ignore,
///         total: total,
///         completed: completed,
///       ),
///     )
///   let parallel.RunRootParallelWithReporterResult(
///     results: results,
///     teardown_failures: _teardown_failures,
///     completed: completed_after_suite,
///     progress_reporter: _progress_reporter,
///   ) = parallel_result
///   results
/// }
/// ```
///
/// ## Parameters
///
/// - `config`: execution settings for this suite
/// - `suite`: the suite to execute
/// - `progress_reporter`: optional progress reporter state (typically `Some(progress.new())`)
/// - `write`: output sink for any progress output (typically `io.print`)
/// - `total`: total number of tests in the overall run (across all suites)
/// - `completed`: number of tests already completed before this suite starts
///
/// ## Returns
///
/// A `RunRootParallelWithReporterResult` containing:
/// - `results`: this suite’s results, in deterministic (declaration) order
/// - `teardown_failures`: this suite’s `after_each`, `after_each_test` and
///   `after_all` hooks that failed, in the order that they ran
/// - `completed`: updated completed count after driving `TestFinished` events
/// - `progress_reporter`: progress reporter state (unchanged for the built-in progress reporter)
pub fn run_root_parallel_with_reporter(
  config config: RunRootParallelWithReporterConfig(context),
) -> RunRootParallelWithReporterResult {
  let RunRootParallelWithReporterConfig(
    config: executor_config,
    suite: suite,
    progress_reporter: progress_reporter,
    write: write,
    total: total,
    completed: completed,
    runner_before_each_test: runner_before_each_test,
    runner_after_each_test: runner_after_each_test,
  ) = config

  let Root(seed: seed, name: name, tags: tags, children: children) = suite
  let executor_input =
    ExecuteNodeConfig(
      config: executor_config,
      scope: [],
      inherited_tags: [],
      context: seed,
      inherited_before_each: [],
      inherited_after_each: [],
      runner_before_each_test: runner_before_each_test,
      runner_after_each_test: runner_after_each_test,
      node: Group(name: name, tags: tags, children: children),
      progress_output: progress_output(progress_reporter, write),
      total: total,
      completed: completed,
      collected: empty_collected(),
    )

  let #(collected, completed_after_suite) = execute_node(executor_input)
  RunRootParallelWithReporterResult(
    results: list.reverse(collected.results_rev),
    teardown_failures: list.reverse(collected.teardown_failures_rev),
    completed: completed_after_suite,
    progress_reporter: progress_reporter,
  )
}

// =============================================================================
// Execution (sequential groups, tests executed with sandbox + timeout)
// =============================================================================

fn execute_node(
  executor_input: ExecuteNodeConfig(context),
) -> #(Collected, Int) {
  let ExecuteNodeConfig(
    config: config,
    scope: scope,
    inherited_tags: inherited_tags,
    context: context,
    inherited_before_each: inherited_before_each,
    inherited_after_each: inherited_after_each,
    runner_before_each_test: runner_before_each_test,
    runner_after_each_test: runner_after_each_test,
    node: node,
    progress_output: progress_output,
    total: total,
    completed: completed,
    collected: base_collected,
  ) = executor_input

  case node {
    Group(name, tags, children) -> {
      let group_scope = list.append(scope, [name])
      let combined_tags = list.append(inherited_tags, tags)
      let empty_hooks =
        GroupHooks(
          before_all: [],
          before_each: [],
          after_each: [],
          after_all: [],
        )
      let #(hooks, tests, groups) =
        collect_children(children, empty_hooks, [], [])
      let #(ctx2, _before_each2, _after_each2, failures_rev) =
        run_before_all_chain(
          group_scope,
          context,
          hooks.before_all,
          inherited_before_each,
          inherited_after_each,
          [],
        )

      case list.is_empty(failures_rev) {
        False -> {
          // If before_all fails, do not execute any tests in this scope.
          // Instead, mark all tests under this group as SetupFailed and skip
          // their bodies.
          let group_results_rev =
            fail_tests_due_to_before_all(
              group_scope,
              combined_tags,
              tests,
              groups,
              failures_rev,
              [],
            )
          // These tests were never spawned as workers, so we must still emit
          // progress events for them to keep the progress bar in sync with
          // `total`.
          let completed_after_failures =
            emit_test_finished_progress_results(
              progress_output,
              completed,
              total,
              list.reverse(group_results_rev),
            )

          let teardown_failures_rev =
            run_after_all_chain(group_scope, ctx2, hooks.after_all, [])

          #(
            add_collected(
              Collected(
                results_rev: group_results_rev,
                teardown_failures_rev: teardown_failures_rev,
              ),
              base_collected,
            ),
            completed_after_failures,
          )
        }

        True -> {
          let combined_before_each =
            list.append(inherited_before_each, hooks.before_each)
          let combined_after_each =
            list.append(hooks.after_each, inherited_after_each)

          let #(group_outcomes_rev, completed_after_tests) =
            run_tests_in_group(
              config,
              group_scope,
              combined_tags,
              ctx2,
              runner_before_each_test,
              runner_after_each_test,
              combined_before_each,
              combined_after_each,
              tests,
              failures_rev,
              progress_output,
              total,
              completed,
            )

          let #(after_groups, completed_after_groups) =
            run_child_groups_sequentially(
              config,
              group_scope,
              combined_tags,
              ctx2,
              runner_before_each_test,
              runner_after_each_test,
              combined_before_each,
              combined_after_each,
              groups,
              progress_output,
              total,
              completed_after_tests,
              collected_from_outcomes_rev(group_outcomes_rev),
            )

          let teardown_failures_rev =
            run_after_all_chain(group_scope, ctx2, hooks.after_all, [])

          #(
            add_collected(
              Collected(
                results_rev: [],
                teardown_failures_rev: teardown_failures_rev,
              ),
              add_collected(after_groups, base_collected),
            ),
            completed_after_groups,
          )
        }
      }
    }

    _ -> #(base_collected, completed)
  }
}

fn empty_collected() -> Collected {
  Collected(results_rev: [], teardown_failures_rev: [])
}

/// Put `newer` in front of `older`. Both lists are newest first.
fn add_collected(newer: Collected, older: Collected) -> Collected {
  Collected(
    results_rev: list.append(newer.results_rev, older.results_rev),
    teardown_failures_rev: list.append(
      newer.teardown_failures_rev,
      older.teardown_failures_rev,
    ),
  )
}

/// The results and tear-down failures of test outcomes that are newest
/// first.
fn collected_from_outcomes_rev(outcomes_rev: List(TestOutcome)) -> Collected {
  Collected(
    results_rev: list.map(outcomes_rev, outcome_result),
    teardown_failures_rev: list.flat_map(
      outcomes_rev,
      outcome_teardown_failures_rev,
    ),
  )
}

fn outcome_result(outcome: TestOutcome) -> TestResult {
  outcome.result
}

fn outcome_teardown_failures_rev(
  outcome: TestOutcome,
) -> List(TeardownFailure) {
  list.reverse(outcome.teardown_failures)
}

fn fail_tests_due_to_before_all(
  scope: List(String),
  inherited_tags: List(String),
  tests: List(TestCase(context)),
  groups: List(Node(context)),
  failures_rev: List(AssertionFailure),
  acc_rev: List(TestResult),
) -> List(TestResult) {
  let after_tests =
    fail_test_nodes(scope, inherited_tags, tests, failures_rev, acc_rev)
  fail_group_nodes(scope, inherited_tags, groups, failures_rev, after_tests)
}

fn fail_test_nodes(
  scope: List(String),
  inherited_tags: List(String),
  test_cases: List(TestCase(context)),
  failures_rev: List(AssertionFailure),
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case test_cases {
    [] -> acc_rev
    [test_case, ..rest] -> {
      let result =
        TestResult(
          name: test_case.name,
          groups: scope,
          status: SetupFailed,
          duration_ms: 0,
          tags: list.append(inherited_tags, test_case.tags),
          failures: list.reverse(failures_rev),
          kind: test_case.kind,
        )
      fail_test_nodes(scope, inherited_tags, rest, failures_rev, [
        result,
        ..acc_rev
      ])
    }
  }
}

fn fail_group_nodes(
  scope: List(String),
  inherited_tags: List(String),
  nodes: List(Node(context)),
  failures_rev: List(AssertionFailure),
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case nodes {
    [] -> acc_rev
    [Group(name, tags, children), ..rest] -> {
      let group_scope = list.append(scope, [name])
      let combined_tags = list.append(inherited_tags, tags)
      let empty_hooks =
        GroupHooks(
          before_all: [],
          before_each: [],
          after_each: [],
          after_all: [],
        )
      let #(_hooks, tests, groups) =
        collect_children(children, empty_hooks, [], [])
      let next =
        fail_tests_due_to_before_all(
          group_scope,
          combined_tags,
          tests,
          groups,
          failures_rev,
          acc_rev,
        )
      fail_group_nodes(scope, inherited_tags, rest, failures_rev, next)
    }
    [_other, ..rest] ->
      fail_group_nodes(scope, inherited_tags, rest, failures_rev, acc_rev)
  }
}

type GroupHooks(context) {
  GroupHooks(
    before_all: List(Callback(context, Result(context, String))),
    before_each: List(Callback(context, Result(context, String))),
    after_each: List(Callback(context, Result(Nil, String))),
    after_all: List(Callback(context, Result(Nil, String))),
  )
}

fn collect_children(
  children: List(Node(context)),
  hooks: GroupHooks(context),
  tests_rev: List(TestCase(context)),
  groups_rev: List(Node(context)),
) -> #(GroupHooks(context), List(TestCase(context)), List(Node(context))) {
  let hooks0 = case hooks {
    GroupHooks(..) -> hooks
  }

  case children {
    [] -> #(hooks0, list.reverse(tests_rev), list.reverse(groups_rev))
    [child, ..rest] ->
      case child {
        BeforeAll(run) ->
          collect_children(
            rest,
            GroupHooks(
              ..hooks0,
              before_all: list.append(hooks0.before_all, [run]),
            ),
            tests_rev,
            groups_rev,
          )
        BeforeEach(run) ->
          collect_children(
            rest,
            GroupHooks(
              ..hooks0,
              before_each: list.append(hooks0.before_each, [run]),
            ),
            tests_rev,
            groups_rev,
          )
        AfterEach(run) ->
          collect_children(
            rest,
            GroupHooks(
              ..hooks0,
              after_each: list.append(hooks0.after_each, [run]),
            ),
            tests_rev,
            groups_rev,
          )
        AfterAll(run) ->
          collect_children(
            rest,
            GroupHooks(
              ..hooks0,
              after_all: list.append(hooks0.after_all, [run]),
            ),
            tests_rev,
            groups_rev,
          )
        Test(name, tags, kind, run, timeout_ms, source) ->
          collect_children(
            rest,
            hooks0,
            [TestCase(name, tags, kind, run, timeout_ms, source), ..tests_rev],
            groups_rev,
          )
        Group(..) ->
          collect_children(rest, hooks0, tests_rev, [child, ..groups_rev])
      }
  }
}

fn run_before_all_chain(
  scope: List(String),
  context: context,
  hooks: List(Callback(context, Result(context, String))),
  inherited_before_each: List(Callback(context, Result(context, String))),
  inherited_after_each: List(Callback(context, Result(Nil, String))),
  failures_rev: List(AssertionFailure),
) -> #(
  context,
  List(Callback(context, Result(context, String))),
  List(Callback(context, Result(Nil, String))),
  List(AssertionFailure),
) {
  case hooks {
    [] -> #(
      context,
      list.append(inherited_before_each, []),
      list.append([], inherited_after_each),
      failures_rev,
    )
    [hook, ..rest] ->
      case run_hook_in_process(scope, hook, context) {
        Ok(next) ->
          run_before_all_chain(
            scope,
            next,
            rest,
            inherited_before_each,
            inherited_after_each,
            failures_rev,
          )
        Error(message) -> #(
          context,
          inherited_before_each,
          inherited_after_each,
          [hook_failure("before_all", message), ..failures_rev],
        )
      }
  }
}

fn run_tests_in_group(
  config: ParallelConfig,
  scope: List(String),
  inherited_tags: List(String),
  context: context,
  runner_before_each_test: List(
    fn(TestInfo, context) -> Result(context, String),
  ),
  runner_after_each_test: List(fn(TestInfo, context) -> Result(Nil, String)),
  before_each_hooks: List(Callback(context, Result(context, String))),
  after_each_hooks: List(Callback(context, Result(Nil, String))),
  tests: List(TestCase(context)),
  failures_rev: List(AssertionFailure),
  progress_output: Option(ProgressOutput),
  total: Int,
  completed: Int,
) -> #(List(TestOutcome), Int) {
  let ParallelConfig(max_concurrency: max_concurrency, default_timeout_ms: _) =
    config
  case max_concurrency <= 1 {
    True ->
      run_tests_sequentially(
        config,
        scope,
        inherited_tags,
        context,
        runner_before_each_test,
        runner_after_each_test,
        before_each_hooks,
        after_each_hooks,
        tests,
        failures_rev,
        progress_output,
        total,
        completed,
        [],
      )
    False ->
      run_tests_parallel(
        config,
        scope,
        inherited_tags,
        context,
        runner_before_each_test,
        runner_after_each_test,
        before_each_hooks,
        after_each_hooks,
        tests,
        failures_rev,
        progress_output,
        total,
        completed,
      )
  }
}

fn run_tests_parallel(
  config: ParallelConfig,
  scope: List(String),
  inherited_tags: List(String),
  context: context,
  runner_before_each_test: List(
    fn(TestInfo, context) -> Result(context, String),
  ),
  runner_after_each_test: List(fn(TestInfo, context) -> Result(Nil, String)),
  before_each_hooks: List(Callback(context, Result(context, String))),
  after_each_hooks: List(Callback(context, Result(Nil, String))),
  tests: List(TestCase(context)),
  failures_rev: List(AssertionFailure),
  progress_output: Option(ProgressOutput),
  total: Int,
  completed: Int,
) -> #(List(TestOutcome), Int) {
  let subject = new_subject()
  let indexed = index_tests(tests, 0, [])
  let ParallelConfig(max_concurrency: max_concurrency, default_timeout_ms: _) =
    config

  run_parallel_loop(RunParallelLoopConfig(
    config: config,
    subject: subject,
    scope: scope,
    inherited_tags: inherited_tags,
    context: context,
    runner_before_each_test: runner_before_each_test,
    runner_after_each_test: runner_after_each_test,
    before_each_hooks: before_each_hooks,
    after_each_hooks: after_each_hooks,
    failures_rev: failures_rev,
    pending: indexed,
    running: [],
    pending_emit: [],
    emitted_rev: [],
    next_emit_index: 0,
    progress_output: progress_output,
    total: total,
    completed: completed,
    max_concurrency: max_concurrency,
  ))
}

fn index_tests(
  test_cases: List(TestCase(context)),
  next_index: Int,
  acc_rev: List(#(Int, TestCase(context))),
) -> List(#(Int, TestCase(context))) {
  case test_cases {
    [] -> list.reverse(acc_rev)
    [test_case, ..rest] ->
      index_tests(rest, next_index + 1, [#(next_index, test_case), ..acc_rev])
  }
}

fn run_parallel_loop(
  loop: RunParallelLoopConfig(context),
) -> #(List(TestOutcome), Int) {
  let RunParallelLoopConfig(
    config: config,
    subject: subject,
    scope: scope,
    inherited_tags: inherited_tags,
    context: context,
    runner_before_each_test: runner_before_each_test,
    runner_after_each_test: runner_after_each_test,
    before_each_hooks: before_each_hooks,
    after_each_hooks: after_each_hooks,
    failures_rev: failures_rev,
    pending: pending,
    running: running,
    pending_emit: pending_emit,
    emitted_rev: emitted_rev,
    next_emit_index: next_emit_index,
    progress_output: progress_output,
    total: total,
    completed: completed,
    max_concurrency: max_concurrency,
  ) = loop

  let #(pending2, running2) =
    start_workers_up_to_limit(StartWorkersUpToLimitConfig(
      config: config,
      subject: subject,
      scope: scope,
      inherited_tags: inherited_tags,
      context: context,
      runner_before_each_test: runner_before_each_test,
      runner_after_each_test: runner_after_each_test,
      before_each_hooks: before_each_hooks,
      after_each_hooks: after_each_hooks,
      failures_rev: failures_rev,
      pending: pending,
      running: running,
      max_concurrency: max_concurrency,
    ))

  case list.is_empty(pending2) && list.is_empty(running2) {
    True -> #(
      list.append(
        list.reverse(emit_all_results(pending_emit, next_emit_index, [])),
        emitted_rev,
      ),
      completed,
    )
    False -> {
      let #(running3, pending_emit2, completed2) =
        wait_for_result(WaitForResultConfig(
          subject: subject,
          scope: scope,
          inherited_tags: inherited_tags,
          running: running2,
          pending_emit: pending_emit,
          progress_output: progress_output,
          total: total,
          completed: completed,
        ))

      let #(maybe_ready, remaining_emit) =
        take_indexed_result(next_emit_index, pending_emit2, [])

      case maybe_ready {
        None ->
          run_parallel_loop(
            RunParallelLoopConfig(
              ..loop,
              pending: pending2,
              running: running3,
              pending_emit: remaining_emit,
              completed: completed2,
            ),
          )
        Some(IndexedResult(_, outcome)) ->
          run_parallel_loop(
            RunParallelLoopConfig(
              ..loop,
              pending: pending2,
              running: running3,
              pending_emit: remaining_emit,
              emitted_rev: [outcome, ..emitted_rev],
              next_emit_index: next_emit_index + 1,
              completed: completed2,
            ),
          )
      }
    }
  }
}

fn emit_all_results(
  pending_emit: List(IndexedResult),
  next_index: Int,
  acc_rev: List(TestOutcome),
) -> List(TestOutcome) {
  let #(maybe_ready, remaining) =
    take_indexed_result(next_index, pending_emit, [])
  case maybe_ready {
    None -> list.reverse(acc_rev)
    Some(IndexedResult(_, outcome)) ->
      emit_all_results(remaining, next_index + 1, [outcome, ..acc_rev])
  }
}

fn start_workers_up_to_limit(
  input: StartWorkersUpToLimitConfig(context),
) -> #(List(#(Int, TestCase(context))), List(RunningWorker(context))) {
  case input.pending, list.length(input.running) < input.max_concurrency {
    [#(index, test_case), ..rest], True -> {
      let worker = spawn_test_worker(input, index, test_case)
      let running_worker =
        RunningWorker(
          monitor: monitor(worker),
          index: index,
          test_case: test_case,
        )
      start_workers_up_to_limit(
        StartWorkersUpToLimitConfig(..input, pending: rest, running: [
          running_worker,
          ..input.running
        ]),
      )
    }
    _, _ -> #(input.pending, input.running)
  }
}

/// Run one test in a new process that sends its result to the loop. The
/// test can time out or crash only in its sandbox, so the worker always
/// sends a result. The caller monitors the worker: if the worker exits
/// before it sends its result, because something outside this module
/// stopped it or because of a bug in this module, the down message gives
/// a failed result with the exit reason.
fn spawn_test_worker(
  input: StartWorkersUpToLimitConfig(context),
  index: Int,
  test_case: TestCase(context),
) -> Pid {
  // The worker gets only what one test needs, not the queue of the loop.
  let worker_input =
    StartWorkersUpToLimitConfig(..input, pending: [], running: [])
  spawn_unlinked(fn() { run_test_worker(worker_input, index, test_case) })
}

/// The body of a test worker process: run the test and send its result to
/// the loop.
fn run_test_worker(
  input: StartWorkersUpToLimitConfig(context),
  index: Int,
  test_case: TestCase(context),
) -> Nil {
  let outcome =
    execute_one_test_node(
      input.config,
      input.scope,
      input.inherited_tags,
      input.context,
      input.runner_before_each_test,
      input.runner_after_each_test,
      input.before_each_hooks,
      input.after_each_hooks,
      input.failures_rev,
      test_case,
    )
  send(input.subject, WorkerFinished(index: index, outcome: outcome))
}

fn worker_crash_result(
  scope: List(String),
  inherited_tags: List(String),
  test_case: TestCase(context),
  reason: String,
) -> TestOutcome {
  let result =
    TestResult(
      name: test_case.name,
      groups: scope,
      status: Failed,
      duration_ms: 0,
      tags: list.append(inherited_tags, test_case.tags),
      failures: [
        hook_failure(
          "crash",
          "worker crashed in " <> string.join(scope, " > ") <> ": " <> reason,
        ),
      ],
      kind: test_case.kind,
    )
  TestOutcome(result: result, teardown_failures: [])
}

/// Wait for the next result of a worker. There is no deadline here: each
/// test body and hook has its own deadline in its sandbox, so every worker
/// sends a result or, if something stops it first, a down message.
fn wait_for_result(
  input: WaitForResultConfig(context),
) -> #(List(RunningWorker(context)), List(IndexedResult), Int) {
  let message =
    new_selector()
    |> select(input.subject)
    |> select_worker_monitors(input.running)
    |> selector_receive_forever()
  let #(still_running, new_results) = case message {
    WorkerFinished(index: index, outcome: outcome) -> #(
      remove_finished_worker(input.running, index, []),
      [IndexedResult(index: index, outcome: outcome)],
    )
    WorkerDown(down: down) ->
      remove_down_worker(input, input.running, down, [], [])
  }
  let next_completed =
    emit_test_finished_progress_results(
      input.progress_output,
      input.completed,
      input.total,
      list.map(new_results, indexed_result_value),
    )
  #(still_running, list.append(new_results, input.pending_emit), next_completed)
}

/// Select the down message of each running worker. Only these monitors are
/// selected, so other down messages of the calling process stay in its
/// mailbox.
fn select_worker_monitors(
  selector: Selector(WorkerMessage),
  running: List(RunningWorker(context)),
) -> Selector(WorkerMessage) {
  case running {
    [] -> selector
    [worker, ..rest] ->
      selector
      |> select_specific_monitor(worker.monitor, WorkerDown)
      |> select_worker_monitors(rest)
  }
}

/// Remove the worker that sent the result for `index`. A worker sends its
/// result before it exits, so the result comes before the down message;
/// `demonitor_process` also removes a down message that is already in the
/// mailbox.
fn remove_finished_worker(
  running: List(RunningWorker(context)),
  index: Int,
  kept_rev: List(RunningWorker(context)),
) -> List(RunningWorker(context)) {
  case running {
    [] -> list.reverse(kept_rev)
    [worker, ..rest] if worker.index == index -> {
      demonitor_process(worker.monitor)
      remove_finished_worker(rest, index, kept_rev)
    }
    [worker, ..rest] ->
      remove_finished_worker(rest, index, [worker, ..kept_rev])
  }
}

/// Remove the worker of the monitor that sent a down message, and give a
/// failed result for its test: the worker exited before it sent its result.
fn remove_down_worker(
  input: WaitForResultConfig(context),
  running: List(RunningWorker(context)),
  down: Down,
  kept_rev: List(RunningWorker(context)),
  results: List(IndexedResult),
) -> #(List(RunningWorker(context)), List(IndexedResult)) {
  case running {
    [] -> #(list.reverse(kept_rev), results)
    [worker, ..rest] if worker.monitor == down.monitor ->
      remove_down_worker(input, rest, down, kept_rev, [
        IndexedResult(
          index: worker.index,
          outcome: worker_crash_result(
            input.scope,
            input.inherited_tags,
            worker.test_case,
            sandbox.format_exit_reason(down.reason),
          ),
        ),
        ..results
      ])
    [worker, ..rest] ->
      remove_down_worker(input, rest, down, [worker, ..kept_rev], results)
  }
}

fn indexed_result_value(indexed_result: IndexedResult) -> TestResult {
  indexed_result.outcome.result
}

fn emit_test_finished_progress(
  progress_output: Option(ProgressOutput),
  completed: Int,
  total: Int,
  result: TestResult,
) -> Int {
  let next_completed = completed + 1
  case progress_output {
    None -> next_completed
    Some(ProgressOutput(reporter: reporter, write: write)) -> {
      write(progress.line(
        reporter,
        progress.TestFinishedProgress(
          completed: next_completed,
          total: total,
          result: result,
        ),
      ))
      next_completed
    }
  }
}

fn emit_test_finished_progress_results(
  progress_output: Option(ProgressOutput),
  completed: Int,
  total: Int,
  results: List(TestResult),
) -> Int {
  case results {
    [] -> completed
    [result, ..rest] -> {
      let next_completed =
        emit_test_finished_progress(progress_output, completed, total, result)
      emit_test_finished_progress_results(
        progress_output,
        next_completed,
        total,
        rest,
      )
    }
  }
}

fn take_indexed_result(
  index: Int,
  items: List(IndexedResult),
  acc_rev: List(IndexedResult),
) -> #(Option(IndexedResult), List(IndexedResult)) {
  case items {
    [] -> #(None, list.reverse(acc_rev))
    [item, ..rest] ->
      case item.index == index {
        True -> #(Some(item), list.append(list.reverse(acc_rev), rest))
        False -> take_indexed_result(index, rest, [item, ..acc_rev])
      }
  }
}

fn execute_one_test_node(
  config: ParallelConfig,
  scope: List(String),
  inherited_tags: List(String),
  context: context,
  runner_before_each_test: List(
    fn(TestInfo, context) -> Result(context, String),
  ),
  runner_after_each_test: List(fn(TestInfo, context) -> Result(Nil, String)),
  before_each_hooks: List(Callback(context, Result(context, String))),
  after_each_hooks: List(Callback(context, Result(Nil, String))),
  failures_rev: List(AssertionFailure),
  test_case: TestCase(context),
) -> TestOutcome {
  let TestCase(
    name: name,
    tags: tags,
    kind: kind,
    run: run,
    timeout_ms: timeout_ms,
    source: source,
  ) = test_case
  let all_tags = list.append(inherited_tags, tags)
  let info =
    types.TestInfo(
      name: name,
      groups: scope,
      tags: all_tags,
      kind: kind,
      source: source,
    )
  let start = timing.now_ms()

  let #(ctx_after_runner_setup, runner_setup_status, runner_setup_failures) =
    run_runner_before_each_list(
      config,
      scope,
      info,
      context,
      runner_before_each_test,
      [],
    )

  let #(ctx_after_setup, setup_status, setup_failures) = case
    runner_setup_status
  {
    SetupFailed -> #(ctx_after_runner_setup, SetupFailed, runner_setup_failures)
    _ ->
      run_before_each_list(
        config,
        scope,
        ctx_after_runner_setup,
        before_each_hooks,
        runner_setup_failures,
      )
  }

  let #(status, failures) = case setup_status {
    SetupFailed ->
      setup_failed_status_and_failures(failures_rev, setup_failures)
    _ -> {
      run_in_sandbox(
        config,
        timeout_ms,
        TestBody(run: run, context: ctx_after_setup),
      )
      |> sandbox_status_and_failures(failures_rev, setup_failures)
    }
  }

  let test_name = types.full_name(scope, name)
  let after_each_failures_rev =
    run_after_each_list(
      config,
      scope,
      test_name,
      ctx_after_setup,
      after_each_hooks,
      [],
    )

  let teardown_failures_rev =
    run_runner_after_each_list(
      config,
      scope,
      test_name,
      info,
      ctx_after_setup,
      runner_after_each_test,
      after_each_failures_rev,
    )

  let duration = timing.now_ms() - start

  TestOutcome(
    result: TestResult(
      name: name,
      groups: scope,
      status: status,
      duration_ms: duration,
      tags: all_tags,
      failures: list.reverse(failures),
      kind: kind,
    ),
    teardown_failures: list.reverse(teardown_failures_rev),
  )
}

fn run_tests_sequentially(
  config: ParallelConfig,
  scope: List(String),
  inherited_tags: List(String),
  context: context,
  runner_before_each_test: List(
    fn(TestInfo, context) -> Result(context, String),
  ),
  runner_after_each_test: List(fn(TestInfo, context) -> Result(Nil, String)),
  before_each_hooks: List(Callback(context, Result(context, String))),
  after_each_hooks: List(Callback(context, Result(Nil, String))),
  tests: List(TestCase(context)),
  failures_rev: List(AssertionFailure),
  progress_output: Option(ProgressOutput),
  total: Int,
  completed: Int,
  acc_rev: List(TestOutcome),
) -> #(List(TestOutcome), Int) {
  case tests {
    [] -> #(acc_rev, completed)
    [test_case, ..rest] -> {
      let outcome =
        execute_one_test_node(
          config,
          scope,
          inherited_tags,
          context,
          runner_before_each_test,
          runner_after_each_test,
          before_each_hooks,
          after_each_hooks,
          failures_rev,
          test_case,
        )

      let next_completed =
        emit_test_finished_progress(
          progress_output,
          completed,
          total,
          outcome.result,
        )
      run_tests_sequentially(
        config,
        scope,
        inherited_tags,
        context,
        runner_before_each_test,
        runner_after_each_test,
        before_each_hooks,
        after_each_hooks,
        rest,
        failures_rev,
        progress_output,
        total,
        next_completed,
        [outcome, ..acc_rev],
      )
    }
  }
}

fn run_child_groups_sequentially(
  config: ParallelConfig,
  scope: List(String),
  inherited_tags: List(String),
  context: context,
  runner_before_each_test: List(
    fn(TestInfo, context) -> Result(context, String),
  ),
  runner_after_each_test: List(fn(TestInfo, context) -> Result(Nil, String)),
  before_each_hooks: List(Callback(context, Result(context, String))),
  after_each_hooks: List(Callback(context, Result(Nil, String))),
  groups: List(Node(context)),
  progress_output: Option(ProgressOutput),
  total: Int,
  completed: Int,
  collected: Collected,
) -> #(Collected, Int) {
  case groups {
    [] -> #(collected, completed)
    [group_node, ..rest] -> {
      let #(next_collected, next_completed) =
        execute_node(ExecuteNodeConfig(
          config: config,
          scope: scope,
          inherited_tags: inherited_tags,
          context: context,
          inherited_before_each: before_each_hooks,
          inherited_after_each: after_each_hooks,
          runner_before_each_test: runner_before_each_test,
          runner_after_each_test: runner_after_each_test,
          node: group_node,
          progress_output: progress_output,
          total: total,
          completed: completed,
          collected: collected,
        ))
      run_child_groups_sequentially(
        config,
        scope,
        inherited_tags,
        context,
        runner_before_each_test,
        runner_after_each_test,
        before_each_hooks,
        after_each_hooks,
        rest,
        progress_output,
        total,
        next_completed,
        next_collected,
      )
    }
  }
}

/// Run every `after_all` hook of a group, also after one fails, and give
/// the failures newest first, in front of `failures_rev`.
fn run_after_all_chain(
  scope: List(String),
  context: context,
  hooks: List(Callback(context, Result(Nil, String))),
  failures_rev: List(TeardownFailure),
) -> List(TeardownFailure) {
  case hooks {
    [] -> failures_rev
    [hook, ..rest] ->
      run_after_all_chain(
        scope,
        context,
        rest,
        add_teardown_failure(
          run_hook_in_process(scope, hook, context),
          AfterAllHook,
          scope,
          failures_rev,
        ),
      )
  }
}

/// Put a failure of a tear-down hook in front of `failures_rev`. A hook
/// that succeeded adds nothing.
fn add_teardown_failure(
  hook_result: Result(Nil, String),
  hook: TeardownHook,
  scope: List(String),
  failures_rev: List(TeardownFailure),
) -> List(TeardownFailure) {
  case hook_result {
    Ok(Nil) -> failures_rev
    Error(message) -> [
      TeardownFailure(hook: hook, scope: scope, message: message),
      ..failures_rev
    ]
  }
}

// =============================================================================
// Hook helpers
// =============================================================================

/// A runner hook with the two arguments it gets, so that it can run in a
/// sandbox as a function of one input.
type RunnerHookCall(context, output) {
  RunnerHookCall(
    hook: fn(TestInfo, context) -> output,
    info: TestInfo,
    context: context,
  )
}

fn call_runner_hook(call: RunnerHookCall(context, output)) -> output {
  call.hook(call.info, call.context)
}

/// A group hook with its input, so that it can run in a sandbox as a
/// function of one input.
type HookCall(input, output) {
  HookCall(hook: Callback(input, output), input: input)
}

fn call_hook(call: HookCall(input, output)) -> output {
  types.call(call.hook, call.input)
}

/// Run one hook with its input in a sandbox. A timeout or a crash becomes
/// an `Error` that names the scope.
fn run_hook(
  config: ParallelConfig,
  scope: List(String),
  hook: fn(input) -> Result(output, String),
  input: input,
) -> Result(output, String) {
  let sandbox_config =
    sandbox.SandboxConfig(
      timeout_ms: config.default_timeout_ms,
      show_crash_reports: False,
    )
  case sandbox.run_isolated(sandbox_config, hook, input) {
    sandbox.SandboxCompleted(result) -> result
    sandbox.SandboxTimedOut ->
      Error("hook timed out in " <> string.join(scope, " > "))
    sandbox.SandboxCrashed(reason) -> Error(hook_crash_message(scope, reason))
  }
}

/// Run a group-level hook (`before_all` or `after_all`) in the process that
/// runs the group. A crash becomes an `Error` that names the scope.
///
/// The hook does not run in a sandbox: a resource that it starts, such as a
/// pool that links to the caller or an ETS table, must live for all the
/// tests of the group, and a sandbox process stops when the hook returns.
/// So no timeout applies to these hooks.
fn run_hook_in_process(
  scope: List(String),
  hook: Callback(input, Result(output, String)),
  input: input,
) -> Result(output, String) {
  case sandbox.run_catching(call_hook, HookCall(hook: hook, input: input)) {
    Ok(result) -> result
    Error(reason) -> Error(hook_crash_message(scope, reason))
  }
}

fn hook_crash_message(scope: List(String), reason: String) -> String {
  "hook crashed in " <> string.join(scope, " > ") <> ": " <> reason
}

fn run_before_each_list(
  config: ParallelConfig,
  scope: List(String),
  context: context,
  hooks: List(Callback(context, Result(context, String))),
  failures_rev: List(AssertionFailure),
) -> #(context, Status, List(AssertionFailure)) {
  case hooks {
    [] -> #(context, Passed, failures_rev)
    [hook, ..rest] ->
      case
        run_hook(config, scope, call_hook, HookCall(hook: hook, input: context))
      {
        Ok(next) ->
          run_before_each_list(config, scope, next, rest, failures_rev)
        Error(message) -> #(context, SetupFailed, [
          hook_failure("before_each", message),
          ..failures_rev
        ])
      }
  }
}

/// Run every `after_each` hook of a test, also after one fails, and give
/// the failures newest first, in front of `failures_rev`. A failure does
/// not change the status of the test.
fn run_after_each_list(
  config: ParallelConfig,
  scope: List(String),
  test_name: List(String),
  context: context,
  hooks: List(Callback(context, Result(Nil, String))),
  failures_rev: List(TeardownFailure),
) -> List(TeardownFailure) {
  case hooks {
    [] -> failures_rev
    [hook, ..rest] ->
      run_after_each_list(
        config,
        scope,
        test_name,
        context,
        rest,
        add_teardown_failure(
          run_hook(
            config,
            scope,
            call_hook,
            HookCall(hook: hook, input: context),
          ),
          AfterEachHook,
          test_name,
          failures_rev,
        ),
      )
  }
}

fn run_runner_before_each_list(
  config: ParallelConfig,
  scope: List(String),
  info: TestInfo,
  context: context,
  hooks: List(fn(TestInfo, context) -> Result(context, String)),
  failures_rev: List(AssertionFailure),
) -> #(context, Status, List(AssertionFailure)) {
  case hooks {
    [] -> #(context, Passed, failures_rev)
    [hook, ..rest] ->
      case
        run_hook(
          config,
          scope,
          call_runner_hook,
          RunnerHookCall(hook: hook, info: info, context: context),
        )
      {
        Ok(next) ->
          run_runner_before_each_list(
            config,
            scope,
            info,
            next,
            rest,
            failures_rev,
          )
        Error(message) -> #(context, SetupFailed, [
          hook_failure("before_each_test", message),
          ..failures_rev
        ])
      }
  }
}

/// Run every runner `after_each_test` hook of a test, also after one
/// fails, and give the failures newest first, in front of `failures_rev`.
/// A failure does not change the status of the test.
fn run_runner_after_each_list(
  config: ParallelConfig,
  scope: List(String),
  test_name: List(String),
  info: TestInfo,
  context: context,
  hooks: List(fn(TestInfo, context) -> Result(Nil, String)),
  failures_rev: List(TeardownFailure),
) -> List(TeardownFailure) {
  case hooks {
    [] -> failures_rev
    [hook, ..rest] ->
      run_runner_after_each_list(
        config,
        scope,
        test_name,
        info,
        context,
        rest,
        add_teardown_failure(
          run_hook(
            config,
            scope,
            call_runner_hook,
            RunnerHookCall(hook: hook, info: info, context: context),
          ),
          AfterEachTestHook,
          test_name,
          failures_rev,
        ),
      )
  }
}

fn hook_failure(operator: String, message: String) -> AssertionFailure {
  AssertionFailure(operator: operator, message: message, payload: None)
}

fn assertion_to_status_and_failures(
  result: AssertionResult,
  inherited_failures_rev: List(AssertionFailure),
  setup_failures_rev: List(AssertionFailure),
) -> #(Status, List(AssertionFailure)) {
  case result {
    AssertionOk -> #(
      Passed,
      list.append(setup_failures_rev, inherited_failures_rev),
    )
    AssertionFailed(failure) -> #(Failed, [
      failure,
      ..list.append(setup_failures_rev, inherited_failures_rev)
    ])
    AssertionSkipped -> #(
      Skipped,
      list.append(setup_failures_rev, inherited_failures_rev),
    )
  }
}

fn setup_failed_status_and_failures(
  inherited_failures_rev: List(AssertionFailure),
  setup_failures_rev: List(AssertionFailure),
) -> #(Status, List(AssertionFailure)) {
  #(SetupFailed, list.append(setup_failures_rev, inherited_failures_rev))
}

/// A test body with the context that it gets.
type TestBody(context) {
  TestBody(
    run: Callback(context, Result(AssertionResult, String)),
    context: context,
  )
}

/// Run a test body with its context. An `Error` from the body is a failed
/// assertion with the operator `error`.
fn run_test_body(body: TestBody(context)) -> AssertionResult {
  case types.call(body.run, body.context) {
    Ok(result) -> result
    Error(message) -> AssertionFailed(hook_failure("error", message))
  }
}

/// Run a test body in a sandbox. The sandbox timeout is the only deadline
/// of a test, in parallel and in sequential runs.
fn run_in_sandbox(
  config: ParallelConfig,
  timeout_override: Option(Int),
  body: TestBody(context),
) -> sandbox.SandboxResult(AssertionResult) {
  let ParallelConfig(default_timeout_ms: default_timeout_ms, max_concurrency: _) =
    config
  let timeout = case timeout_override {
    Some(ms) -> ms
    None -> default_timeout_ms
  }
  let sandbox_config =
    sandbox.SandboxConfig(timeout_ms: timeout, show_crash_reports: False)
  sandbox.run_isolated(sandbox_config, run_test_body, body)
}

/// The status and failures of a test body from its sandbox result. A body
/// that ran past its timeout is `TimedOut`.
fn sandbox_status_and_failures(
  sandbox_result: sandbox.SandboxResult(AssertionResult),
  inherited_failures_rev: List(AssertionFailure),
  setup_failures_rev: List(AssertionFailure),
) -> #(Status, List(AssertionFailure)) {
  let earlier_failures_rev =
    list.append(setup_failures_rev, inherited_failures_rev)
  case sandbox_result {
    sandbox.SandboxCompleted(assertion) ->
      assertion_to_status_and_failures(
        assertion,
        inherited_failures_rev,
        setup_failures_rev,
      )
    sandbox.SandboxTimedOut -> #(TimedOut, [
      hook_failure("timeout", "test timed out"),
      ..earlier_failures_rev
    ])
    sandbox.SandboxCrashed(reason) -> #(Failed, [
      hook_failure("crash", reason),
      ..earlier_failures_rev
    ])
  }
}
