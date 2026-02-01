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
//// import dream_test/unit.{describe, it}
////
//// pub fn tests() {
////   describe("Parallel executor", [
////     it("can run a suite and return a list of results", fn() {
////       let suite =
////         describe("Suite", [
////           it("a", fn() { Ok(succeed()) }),
////           it("b", fn() { Ok(succeed()) }),
////         ])
////
////       parallel.run_root_parallel(parallel.default_config(), suite)
////       |> should
////       |> have_length(2)
////       |> or_fail_with("expected two results")
////     }),
////   ])
//// }
//// ```

import dream_test/reporters/progress
import dream_test/reporters/types as reporter_types
import dream_test/sandbox
import dream_test/timing
import dream_test/types.{
  type AssertionFailure, type AssertionResult, type Node, type Status,
  type TestInfo, type TestKind, type TestResult, type TestSuite, AfterAll,
  AfterEach, AssertionFailed, AssertionFailure, AssertionOk, AssertionSkipped,
  BeforeAll, BeforeEach, Failed, Group, Passed, Root, SetupFailed, Skipped, Test,
  TestResult, TimedOut, Unit,
}
import gleam/erlang/process.{
  type Pid, type Subject, kill, new_selector, new_subject, select,
  selector_receive, send, spawn_unlinked,
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
/// fields and avoid positional destructuring.
pub type RunRootParallelWithReporterResult {
  RunRootParallelWithReporterResult(
    results: List(TestResult),
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
    inherited_before_each: List(fn(context) -> Result(context, String)),
    inherited_after_each: List(fn(context) -> Result(Nil, String)),
    runner_before_each_test: List(
      fn(TestInfo, context) -> Result(context, String),
    ),
    runner_after_each_test: List(fn(TestInfo, context) -> Result(Nil, String)),
    node: Node(context),
    progress_reporter: Option(progress.ProgressReporter),
    write: fn(String) -> Nil,
    total: Int,
    completed: Int,
    results_rev: List(TestResult),
  )
}

type IndexedResult {
  IndexedResult(index: Int, result: TestResult)
}

type RunningTest {
  RunningTest(
    index: Int,
    pid: Pid,
    deadline_ms: Int,
    name: String,
    full_name: List(String),
    tags: List(String),
    kind: TestKind,
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
    before_each_hooks: List(fn(context) -> Result(context, String)),
    after_each_hooks: List(fn(context) -> Result(Nil, String)),
    failures_rev: List(AssertionFailure),
    pending: List(#(Int, Node(context))),
    running: List(RunningTest),
    pending_emit: List(IndexedResult),
    emitted_rev: List(TestResult),
    next_emit_index: Int,
    progress_reporter: Option(progress.ProgressReporter),
    write: fn(String) -> Nil,
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
    before_each_hooks: List(fn(context) -> Result(context, String)),
    after_each_hooks: List(fn(context) -> Result(Nil, String)),
    failures_rev: List(AssertionFailure),
    pending: List(#(Int, Node(context))),
    running: List(RunningTest),
    max_concurrency: Int,
  )
}

type WaitForEventOrTimeoutConfig(context) {
  WaitForEventOrTimeoutConfig(
    config: ParallelConfig,
    subject: Subject(WorkerMessage),
    scope: List(String),
    pending: List(#(Int, Node(context))),
    running: List(RunningTest),
    pending_emit: List(IndexedResult),
    progress_reporter: Option(progress.ProgressReporter),
    write: fn(String) -> Nil,
    total: Int,
    completed: Int,
  )
}

type WorkerMessage {
  WorkerCompleted(index: Int, result: TestResult)
  WorkerCrashed(index: Int, reason: String)
}

@external(erlang, "sandbox_ffi", "run_catching")
fn run_catching(fn_to_run: fn() -> a) -> Result(a, String)

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
/// import dream_test/unit.{describe, it}
///
/// pub fn tests() {
///   describe("Parallel executor", [
///     it("can run a suite and return a list of results", fn() {
///       let suite =
///         describe("Suite", [
///           it("a", fn() { Ok(succeed()) }),
///           it("b", fn() { Ok(succeed()) }),
///         ])
///
///       parallel.run_root_parallel(parallel.default_config(), suite)
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
/// import dream_test/unit.{describe, it}
///
/// pub fn tests() {
///   describe("Parallel executor", [
///     it("can run a suite and return a list of results", fn() {
///       let suite =
///         describe("Suite", [
///           it("a", fn() { Ok(succeed()) }),
///           it("b", fn() { Ok(succeed()) }),
///         ])
///
///       parallel.run_root_parallel(parallel.default_config(), suite)
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
/// A list of `TestResult` values, in deterministic (declaration) order.
pub fn run_root_parallel(
  config config: ParallelConfig,
  suite suite: TestSuite(context),
) -> List(TestResult) {
  let Root(seed, tree) = suite
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
      node: tree,
      progress_reporter: None,
      write: discard_write,
      total: 0,
      completed: 0,
      results_rev: [],
    )

  let #(results_rev, _completed) = execute_node(executor_input)
  list.reverse(results_rev)
}

fn discard_write(_text: String) -> Nil {
  Nil
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

  let Root(seed, tree) = suite
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
      node: tree,
      progress_reporter: progress_reporter,
      write: write,
      total: total,
      completed: completed,
      results_rev: [],
    )

  let #(results_rev, completed_after_suite) = execute_node(executor_input)
  RunRootParallelWithReporterResult(
    results: list.reverse(results_rev),
    completed: completed_after_suite,
    progress_reporter: progress_reporter,
  )
}

// =============================================================================
// Execution (sequential groups, tests executed with sandbox + timeout)
// =============================================================================

fn execute_node(
  executor_input: ExecuteNodeConfig(context),
) -> #(List(TestResult), Int) {
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
    progress_reporter: progress_reporter,
    write: write,
    total: total,
    completed: completed,
    results_rev: base_results_rev,
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
          config,
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
          // Instead, mark all tests under this group as failed and skip bodies.
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
              progress_reporter,
              write,
              completed,
              total,
              list.reverse(group_results_rev),
            )

          let final_rev =
            run_after_all_chain(
              config,
              group_scope,
              ctx2,
              hooks.after_all,
              group_results_rev,
            )

          #(list.append(final_rev, base_results_rev), completed_after_failures)
        }

        True -> {
          let combined_before_each =
            list.append(inherited_before_each, hooks.before_each)
          let combined_after_each =
            list.append(hooks.after_each, inherited_after_each)

          let #(group_results_rev, completed_after_tests) =
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
              progress_reporter,
              write,
              total,
              completed,
            )

          let #(after_group_rev, completed_after_groups) =
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
              progress_reporter,
              write,
              total,
              completed_after_tests,
              group_results_rev,
            )

          let final_rev =
            run_after_all_chain(
              config,
              group_scope,
              ctx2,
              hooks.after_all,
              after_group_rev,
            )

          #(list.append(final_rev, base_results_rev), completed_after_groups)
        }
      }
    }

    _ -> #(base_results_rev, completed)
  }
}

fn fail_tests_due_to_before_all(
  scope: List(String),
  inherited_tags: List(String),
  tests: List(Node(context)),
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
  nodes: List(Node(context)),
  failures_rev: List(AssertionFailure),
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case nodes {
    [] -> acc_rev
    [Test(name, tags, kind, _run, _timeout_ms, _source), ..rest] -> {
      let full_name = list.append(scope, [name])
      let all_tags = list.append(inherited_tags, tags)
      let failures = list.reverse(failures_rev)
      let result =
        TestResult(
          name: name,
          full_name: full_name,
          status: Failed,
          duration_ms: 0,
          tags: all_tags,
          failures: failures,
          kind: kind,
        )
      fail_test_nodes(scope, inherited_tags, rest, failures_rev, [
        result,
        ..acc_rev
      ])
    }
    [_other, ..rest] ->
      fail_test_nodes(scope, inherited_tags, rest, failures_rev, acc_rev)
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
    before_all: List(fn(context) -> Result(context, String)),
    before_each: List(fn(context) -> Result(context, String)),
    after_each: List(fn(context) -> Result(Nil, String)),
    after_all: List(fn(context) -> Result(Nil, String)),
  )
}

fn collect_children(
  children: List(Node(context)),
  hooks: GroupHooks(context),
  tests_rev: List(Node(context)),
  groups_rev: List(Node(context)),
) -> #(GroupHooks(context), List(Node(context)), List(Node(context))) {
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
        Test(..) ->
          collect_children(rest, hooks0, [child, ..tests_rev], groups_rev)
        Group(..) ->
          collect_children(rest, hooks0, tests_rev, [child, ..groups_rev])
      }
  }
}

fn run_before_all_chain(
  config: ParallelConfig,
  scope: List(String),
  context: context,
  hooks: List(fn(context) -> Result(context, String)),
  inherited_before_each: List(fn(context) -> Result(context, String)),
  inherited_after_each: List(fn(context) -> Result(Nil, String)),
  failures_rev: List(AssertionFailure),
) -> #(
  context,
  List(fn(context) -> Result(context, String)),
  List(fn(context) -> Result(Nil, String)),
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
      case run_hook_transform(config, scope, context, hook) {
        Ok(next) ->
          run_before_all_chain(
            config,
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
  before_each_hooks: List(fn(context) -> Result(context, String)),
  after_each_hooks: List(fn(context) -> Result(Nil, String)),
  tests: List(Node(context)),
  failures_rev: List(AssertionFailure),
  progress_reporter: Option(progress.ProgressReporter),
  write: fn(String) -> Nil,
  total: Int,
  completed: Int,
) -> #(List(TestResult), Int) {
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
        progress_reporter,
        write,
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
        progress_reporter,
        write,
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
  before_each_hooks: List(fn(context) -> Result(context, String)),
  after_each_hooks: List(fn(context) -> Result(Nil, String)),
  tests: List(Node(context)),
  failures_rev: List(AssertionFailure),
  progress_reporter: Option(progress.ProgressReporter),
  write: fn(String) -> Nil,
  total: Int,
  completed: Int,
) -> #(List(TestResult), Int) {
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
    progress_reporter: progress_reporter,
    write: write,
    total: total,
    completed: completed,
    max_concurrency: max_concurrency,
  ))
}

fn index_tests(
  nodes: List(Node(context)),
  next_index: Int,
  acc_rev: List(#(Int, Node(context))),
) -> List(#(Int, Node(context))) {
  case nodes {
    [] -> list.reverse(acc_rev)
    [Test(..) as t, ..rest] ->
      index_tests(rest, next_index + 1, [#(next_index, t), ..acc_rev])
    [_other, ..rest] -> index_tests(rest, next_index, acc_rev)
  }
}

fn run_parallel_loop(
  loop: RunParallelLoopConfig(context),
) -> #(List(TestResult), Int) {
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
    progress_reporter: progress_reporter,
    write: write,
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
      let #(pending3, running3, pending_emit2, completed2) =
        wait_for_event_or_timeout(WaitForEventOrTimeoutConfig(
          config: config,
          subject: subject,
          scope: scope,
          pending: pending2,
          running: running2,
          pending_emit: pending_emit,
          progress_reporter: progress_reporter,
          write: write,
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
              pending: pending3,
              running: running3,
              pending_emit: remaining_emit,
              completed: completed2,
            ),
          )
        Some(IndexedResult(_, result)) ->
          run_parallel_loop(
            RunParallelLoopConfig(
              ..loop,
              pending: pending3,
              running: running3,
              pending_emit: remaining_emit,
              emitted_rev: [result, ..emitted_rev],
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
  acc_rev: List(TestResult),
) -> List(TestResult) {
  let #(maybe_ready, remaining) =
    take_indexed_result(next_index, pending_emit, [])
  case maybe_ready {
    None -> list.reverse(acc_rev)
    Some(IndexedResult(_, result)) ->
      emit_all_results(remaining, next_index + 1, [result, ..acc_rev])
  }
}

fn start_workers_up_to_limit(
  input: StartWorkersUpToLimitConfig(context),
) -> #(List(#(Int, Node(context))), List(RunningTest)) {
  let StartWorkersUpToLimitConfig(
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
  ) = input

  let slots = max_concurrency - list.length(running)
  case slots > 0 && !list.is_empty(pending) {
    False -> #(pending, running)
    True ->
      case pending {
        [] -> #(pending, running)
        [#(index, test_node), ..rest] -> {
          let #(pid, deadline_ms) =
            spawn_test_worker(
              config,
              subject,
              scope,
              inherited_tags,
              context,
              runner_before_each_test,
              runner_after_each_test,
              before_each_hooks,
              after_each_hooks,
              failures_rev,
              index,
              test_node,
            )
          let #(name, full_name, tags, kind) =
            running_test_metadata(scope, inherited_tags, test_node)
          start_workers_up_to_limit(
            StartWorkersUpToLimitConfig(..input, pending: rest, running: [
              RunningTest(
                index: index,
                pid: pid,
                deadline_ms: deadline_ms,
                name: name,
                full_name: full_name,
                tags: tags,
                kind: kind,
              ),
              ..running
            ]),
          )
        }
      }
  }
}

fn running_test_metadata(
  scope: List(String),
  inherited_tags: List(String),
  node: Node(context),
) -> #(String, List(String), List(String), TestKind) {
  case node {
    Test(name, tags, kind, _run, _timeout_ms, _source) -> #(
      name,
      list.append(scope, [name]),
      list.append(inherited_tags, tags),
      kind,
    )
    _ -> #("<unknown>", list.append(scope, ["<unknown>"]), inherited_tags, Unit)
  }
}

fn spawn_test_worker(
  config: ParallelConfig,
  subject: Subject(WorkerMessage),
  scope: List(String),
  inherited_tags: List(String),
  context: context,
  runner_before_each_test: List(
    fn(TestInfo, context) -> Result(context, String),
  ),
  runner_after_each_test: List(fn(TestInfo, context) -> Result(Nil, String)),
  before_each_hooks: List(fn(context) -> Result(context, String)),
  after_each_hooks: List(fn(context) -> Result(Nil, String)),
  failures_rev: List(AssertionFailure),
  index: Int,
  node: Node(context),
) -> #(Pid, Int) {
  let start = timing.now_ms()
  let timeout_ms = test_timeout_ms(config, node)
  let pid =
    spawn_unlinked(fn() {
      case
        run_catching(fn() {
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
            node,
          )
        })
      {
        Ok(result) ->
          send(subject, WorkerCompleted(index: index, result: result))
        Error(reason) ->
          send(subject, WorkerCrashed(index: index, reason: reason))
      }
    })
  let deadline_ms = start + timeout_ms
  #(pid, deadline_ms)
}

fn test_timeout_ms(config: ParallelConfig, node: Node(context)) -> Int {
  let ParallelConfig(default_timeout_ms: default_timeout_ms, max_concurrency: _) =
    config
  case node {
    Test(_, _, _, _, Some(ms), _) -> ms
    _ -> default_timeout_ms
  }
}

fn wait_for_event_or_timeout(
  input: WaitForEventOrTimeoutConfig(context),
) -> #(List(#(Int, Node(context))), List(RunningTest), List(IndexedResult), Int) {
  let WaitForEventOrTimeoutConfig(
    config: config,
    subject: subject,
    scope: scope,
    pending: pending,
    running: running,
    pending_emit: pending_emit,
    progress_reporter: progress_reporter,
    write: write,
    total: total,
    completed: completed,
  ) = input

  let selector = new_selector() |> select(subject)

  let now = timing.now_ms()
  let next_timeout = next_deadline_timeout(running, now, 1000)
  case selector_receive(selector, next_timeout) {
    Ok(message) ->
      handle_worker_message(
        scope,
        message,
        pending,
        running,
        pending_emit,
        progress_reporter,
        write,
        total,
        completed,
      )
    Error(Nil) ->
      handle_timeouts(
        config,
        pending,
        running,
        pending_emit,
        progress_reporter,
        write,
        total,
        completed,
      )
  }
}

fn handle_worker_message(
  scope: List(String),
  message: WorkerMessage,
  pending: List(#(Int, Node(context))),
  running: List(RunningTest),
  pending_emit: List(IndexedResult),
  progress_reporter: Option(progress.ProgressReporter),
  write: fn(String) -> Nil,
  total: Int,
  completed: Int,
) -> #(List(#(Int, Node(context))), List(RunningTest), List(IndexedResult), Int) {
  case message {
    WorkerCompleted(index, result) -> {
      let next_completed =
        emit_test_finished_progress(
          progress_reporter,
          write,
          completed,
          total,
          result,
        )
      #(
        pending,
        remove_running_by_index(running, index),
        [IndexedResult(index: index, result: result), ..pending_emit],
        next_completed,
      )
    }
    WorkerCrashed(index, reason) -> {
      let failure =
        hook_failure(
          "crash",
          "worker crashed in " <> string.join(scope, " > ") <> ": " <> reason,
        )
      let #(name, full_name, tags, kind) = case
        get_running_by_index(running, index)
      {
        Some(r) -> #(r.name, r.full_name, r.tags, r.kind)
        None -> #("<crash>", list.append(scope, ["<crash>"]), [], Unit)
      }
      let result =
        TestResult(
          name: name,
          full_name: full_name,
          status: Failed,
          duration_ms: 0,
          tags: tags,
          failures: [failure],
          kind: kind,
        )
      let next_completed =
        emit_test_finished_progress(
          progress_reporter,
          write,
          completed,
          total,
          result,
        )
      #(
        pending,
        remove_running_by_index(running, index),
        [IndexedResult(index: index, result: result), ..pending_emit],
        next_completed,
      )
    }
  }
}

fn get_running_by_index(
  running: List(RunningTest),
  index: Int,
) -> option.Option(RunningTest) {
  case running {
    [] -> None
    [r, ..rest] ->
      case r.index == index {
        True -> Some(r)
        False -> get_running_by_index(rest, index)
      }
  }
}

fn handle_timeouts(
  _config: ParallelConfig,
  pending: List(#(Int, Node(context))),
  running: List(RunningTest),
  pending_emit: List(IndexedResult),
  progress_reporter: Option(progress.ProgressReporter),
  write: fn(String) -> Nil,
  total: Int,
  completed: Int,
) -> #(List(#(Int, Node(context))), List(RunningTest), List(IndexedResult), Int) {
  let now = timing.now_ms()
  let #(timed_out, still_running) = partition_timeouts(running, now, [], [])
  list.each(timed_out, fn(r) { kill(r.pid) })
  let timeout_results = list.map(timed_out, fn(r) { timeout_result(r) })
  let next_completed =
    emit_test_finished_progress_list(
      progress_reporter,
      write,
      completed,
      total,
      timeout_results,
    )
  #(
    pending,
    still_running,
    list.append(timeout_results, pending_emit),
    next_completed,
  )
}

fn timeout_result(running: RunningTest) -> IndexedResult {
  let failure = hook_failure("timeout", "test timed out")
  let RunningTest(
    index: index,
    pid: _pid,
    deadline_ms: _deadline_ms,
    name: name,
    full_name: full_name,
    tags: tags,
    kind: kind,
  ) = running
  let result =
    TestResult(
      name: name,
      full_name: full_name,
      status: TimedOut,
      duration_ms: 0,
      tags: tags,
      failures: [failure],
      kind: kind,
    )
  IndexedResult(index: index, result: result)
}

fn emit_test_finished_progress(
  progress_reporter: Option(progress.ProgressReporter),
  write: fn(String) -> Nil,
  completed: Int,
  total: Int,
  result: TestResult,
) -> Int {
  let next_completed = completed + 1
  case progress_reporter {
    None -> next_completed
    Some(reporter) -> {
      case
        progress.handle_event(
          reporter,
          reporter_types.TestFinished(
            completed: next_completed,
            total: total,
            result: result,
          ),
        )
      {
        None -> Nil
        Some(text) -> write(text)
      }
      next_completed
    }
  }
}

fn emit_test_finished_progress_list(
  progress_reporter: Option(progress.ProgressReporter),
  write: fn(String) -> Nil,
  completed: Int,
  total: Int,
  results: List(IndexedResult),
) -> Int {
  case results {
    [] -> completed
    [IndexedResult(index: _index, result: result), ..rest] -> {
      let next_completed =
        emit_test_finished_progress(
          progress_reporter,
          write,
          completed,
          total,
          result,
        )
      emit_test_finished_progress_list(
        progress_reporter,
        write,
        next_completed,
        total,
        rest,
      )
    }
  }
}

fn emit_test_finished_progress_results(
  progress_reporter: Option(progress.ProgressReporter),
  write: fn(String) -> Nil,
  completed: Int,
  total: Int,
  results: List(TestResult),
) -> Int {
  case results {
    [] -> completed
    [result, ..rest] -> {
      let next_completed =
        emit_test_finished_progress(
          progress_reporter,
          write,
          completed,
          total,
          result,
        )
      emit_test_finished_progress_results(
        progress_reporter,
        write,
        next_completed,
        total,
        rest,
      )
    }
  }
}

fn partition_timeouts(
  running: List(RunningTest),
  now: Int,
  timed_out_rev: List(RunningTest),
  still_rev: List(RunningTest),
) -> #(List(RunningTest), List(RunningTest)) {
  case running {
    [] -> #(list.reverse(timed_out_rev), list.reverse(still_rev))
    [r, ..rest] ->
      case r.deadline_ms <= now {
        True -> partition_timeouts(rest, now, [r, ..timed_out_rev], still_rev)
        False -> partition_timeouts(rest, now, timed_out_rev, [r, ..still_rev])
      }
  }
}

fn next_deadline_timeout(
  running: List(RunningTest),
  now: Int,
  fallback: Int,
) -> Int {
  case running {
    [] -> fallback
    [r, ..rest] -> min_deadline_timeout(rest, now, r.deadline_ms - now)
  }
}

fn min_deadline_timeout(
  running: List(RunningTest),
  now: Int,
  current: Int,
) -> Int {
  case running {
    [] ->
      case current < 0 {
        True -> 0
        False -> current
      }
    [r, ..rest] -> {
      let d = r.deadline_ms - now
      let next = case d < current {
        True -> d
        False -> current
      }
      min_deadline_timeout(rest, now, next)
    }
  }
}

fn remove_running_by_index(
  running: List(RunningTest),
  index: Int,
) -> List(RunningTest) {
  list.filter(running, fn(r) { r.index != index })
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
  before_each_hooks: List(fn(context) -> Result(context, String)),
  after_each_hooks: List(fn(context) -> Result(Nil, String)),
  failures_rev: List(AssertionFailure),
  node: Node(context),
) -> TestResult {
  // Fallback to sequential single-test logic by reusing existing code path.
  case node {
    Test(name, tags, kind, run, timeout_ms, source) -> {
      let full_name = list.append(scope, [name])
      let all_tags = list.append(inherited_tags, tags)
      let info =
        types.TestInfo(
          name: name,
          full_name: full_name,
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
        SetupFailed -> #(
          ctx_after_runner_setup,
          SetupFailed,
          runner_setup_failures,
        )
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
          let assertion =
            run_in_sandbox(config, timeout_ms, fn() {
              case run(ctx_after_setup) {
                Ok(a) -> a
                Error(message) ->
                  AssertionFailed(hook_failure("error", message))
              }
            })
          assertion_to_status_and_failures(
            assertion,
            failures_rev,
            setup_failures,
          )
        }
      }

      let #(status_after_suite, failures_after_suite) =
        run_after_each_list(
          config,
          scope,
          ctx_after_setup,
          after_each_hooks,
          status,
          failures,
        )

      let #(final_status, final_failures) =
        run_runner_after_each_list(
          config,
          scope,
          info,
          ctx_after_setup,
          runner_after_each_test,
          status_after_suite,
          failures_after_suite,
        )

      let duration = timing.now_ms() - start

      TestResult(
        name: name,
        full_name: full_name,
        status: final_status,
        duration_ms: duration,
        tags: all_tags,
        failures: list.reverse(final_failures),
        kind: kind,
      )
    }
    _ ->
      TestResult(
        name: "<invalid>",
        full_name: list.append(scope, ["<invalid>"]),
        status: Failed,
        duration_ms: 0,
        tags: [],
        failures: [hook_failure("internal", "non-test node")],
        kind: Unit,
      )
  }
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
  before_each_hooks: List(fn(context) -> Result(context, String)),
  after_each_hooks: List(fn(context) -> Result(Nil, String)),
  tests: List(Node(context)),
  failures_rev: List(AssertionFailure),
  progress_reporter: Option(progress.ProgressReporter),
  write: fn(String) -> Nil,
  total: Int,
  completed: Int,
  acc_rev: List(TestResult),
) -> #(List(TestResult), Int) {
  case tests {
    [] -> #(acc_rev, completed)
    [Test(name, tags, kind, run, timeout_ms, source), ..rest] -> {
      let full_name = list.append(scope, [name])
      let all_tags = list.append(inherited_tags, tags)
      let info =
        types.TestInfo(
          name: name,
          full_name: full_name,
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
        SetupFailed -> #(
          ctx_after_runner_setup,
          SetupFailed,
          runner_setup_failures,
        )
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
          let assertion =
            run_in_sandbox(config, timeout_ms, fn() {
              case run(ctx_after_setup) {
                Ok(a) -> a
                Error(message) ->
                  AssertionFailed(hook_failure("error", message))
              }
            })
          assertion_to_status_and_failures(
            assertion,
            failures_rev,
            setup_failures,
          )
        }
      }

      let #(status_after_suite, failures_after_suite) =
        run_after_each_list(
          config,
          scope,
          ctx_after_setup,
          after_each_hooks,
          status,
          failures,
        )

      let #(final_status, final_failures) =
        run_runner_after_each_list(
          config,
          scope,
          info,
          ctx_after_setup,
          runner_after_each_test,
          status_after_suite,
          failures_after_suite,
        )

      let duration = timing.now_ms() - start

      let result =
        TestResult(
          name: name,
          full_name: full_name,
          status: final_status,
          duration_ms: duration,
          tags: all_tags,
          failures: list.reverse(final_failures),
          kind: kind,
        )

      let next_completed =
        emit_test_finished_progress(
          progress_reporter,
          write,
          completed,
          total,
          result,
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
        progress_reporter,
        write,
        total,
        next_completed,
        [result, ..acc_rev],
      )
    }

    [_other, ..rest] ->
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
        progress_reporter,
        write,
        total,
        completed,
        acc_rev,
      )
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
  before_each_hooks: List(fn(context) -> Result(context, String)),
  after_each_hooks: List(fn(context) -> Result(Nil, String)),
  groups: List(Node(context)),
  progress_reporter: Option(progress.ProgressReporter),
  write: fn(String) -> Nil,
  total: Int,
  completed: Int,
  acc_rev: List(TestResult),
) -> #(List(TestResult), Int) {
  case groups {
    [] -> #(acc_rev, completed)
    [group_node, ..rest] -> {
      let #(next_rev, next_completed) =
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
          progress_reporter: progress_reporter,
          write: write,
          total: total,
          completed: completed,
          results_rev: acc_rev,
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
        progress_reporter,
        write,
        total,
        next_completed,
        next_rev,
      )
    }
  }
}

fn run_after_all_chain(
  config: ParallelConfig,
  scope: List(String),
  context: context,
  hooks: List(fn(context) -> Result(Nil, String)),
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case hooks {
    [] -> acc_rev
    [hook, ..rest] ->
      case run_hook_teardown(config, scope, context, hook) {
        Ok(_) -> run_after_all_chain(config, scope, context, rest, acc_rev)
        Error(message) -> {
          let result =
            TestResult(
              name: "<after_all>",
              full_name: list.append(scope, ["<after_all>"]),
              status: Failed,
              duration_ms: 0,
              tags: [],
              failures: [hook_failure("after_all", message)],
              kind: Unit,
            )
          [result, ..acc_rev]
        }
      }
  }
}

// =============================================================================
// Hook helpers
// =============================================================================

fn run_hook_transform(
  config: ParallelConfig,
  scope: List(String),
  context: context,
  hook: fn(context) -> Result(context, String),
) -> Result(context, String) {
  let ParallelConfig(default_timeout_ms: default_timeout_ms, max_concurrency: _) =
    config
  let sandbox_config =
    sandbox.SandboxConfig(
      timeout_ms: default_timeout_ms,
      show_crash_reports: False,
    )

  case sandbox.run_isolated(sandbox_config, fn() { hook(context) }) {
    sandbox.SandboxCompleted(result) -> result
    sandbox.SandboxTimedOut ->
      Error("hook timed out in " <> string.join(scope, " > "))
    sandbox.SandboxCrashed(reason) ->
      Error("hook crashed in " <> string.join(scope, " > ") <> ": " <> reason)
  }
}

fn run_hook_teardown(
  config: ParallelConfig,
  scope: List(String),
  context: context,
  hook: fn(context) -> Result(Nil, String),
) -> Result(Nil, String) {
  let ParallelConfig(default_timeout_ms: default_timeout_ms, max_concurrency: _) =
    config
  let sandbox_config =
    sandbox.SandboxConfig(
      timeout_ms: default_timeout_ms,
      show_crash_reports: False,
    )

  case sandbox.run_isolated(sandbox_config, fn() { hook(context) }) {
    sandbox.SandboxCompleted(result) -> result
    sandbox.SandboxTimedOut ->
      Error("hook timed out in " <> string.join(scope, " > "))
    sandbox.SandboxCrashed(reason) ->
      Error("hook crashed in " <> string.join(scope, " > ") <> ": " <> reason)
  }
}

fn run_before_each_list(
  config: ParallelConfig,
  scope: List(String),
  context: context,
  hooks: List(fn(context) -> Result(context, String)),
  failures_rev: List(AssertionFailure),
) -> #(context, Status, List(AssertionFailure)) {
  case hooks {
    [] -> #(context, Passed, failures_rev)
    [hook, ..rest] ->
      case run_hook_transform(config, scope, context, hook) {
        Ok(next) ->
          run_before_each_list(config, scope, next, rest, failures_rev)
        Error(message) -> #(context, SetupFailed, [
          hook_failure("before_each", message),
          ..failures_rev
        ])
      }
  }
}

fn run_after_each_list(
  config: ParallelConfig,
  scope: List(String),
  context: context,
  hooks: List(fn(context) -> Result(Nil, String)),
  status: Status,
  failures_rev: List(AssertionFailure),
) -> #(Status, List(AssertionFailure)) {
  case hooks {
    [] -> #(status, failures_rev)
    [hook, ..rest] ->
      case run_hook_teardown(config, scope, context, hook) {
        Ok(_) ->
          run_after_each_list(
            config,
            scope,
            context,
            rest,
            status,
            failures_rev,
          )
        Error(message) ->
          run_after_each_list(config, scope, context, rest, Failed, [
            hook_failure("after_each", message),
            ..failures_rev
          ])
      }
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
      case run_runner_hook_transform(config, scope, info, context, hook) {
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

fn run_runner_after_each_list(
  config: ParallelConfig,
  scope: List(String),
  info: TestInfo,
  context: context,
  hooks: List(fn(TestInfo, context) -> Result(Nil, String)),
  status: Status,
  failures_rev: List(AssertionFailure),
) -> #(Status, List(AssertionFailure)) {
  case hooks {
    [] -> #(status, failures_rev)
    [hook, ..rest] ->
      case run_runner_hook_teardown(config, scope, info, context, hook) {
        Ok(_) ->
          run_runner_after_each_list(
            config,
            scope,
            info,
            context,
            rest,
            status,
            failures_rev,
          )
        Error(message) ->
          run_runner_after_each_list(
            config,
            scope,
            info,
            context,
            rest,
            Failed,
            [hook_failure("after_each_test", message), ..failures_rev],
          )
      }
  }
}

fn run_runner_hook_transform(
  config: ParallelConfig,
  scope: List(String),
  info: TestInfo,
  context: context,
  hook: fn(TestInfo, context) -> Result(context, String),
) -> Result(context, String) {
  let ParallelConfig(default_timeout_ms: default_timeout_ms, max_concurrency: _) =
    config
  let sandbox_config =
    sandbox.SandboxConfig(
      timeout_ms: default_timeout_ms,
      show_crash_reports: False,
    )

  case sandbox.run_isolated(sandbox_config, fn() { hook(info, context) }) {
    sandbox.SandboxCompleted(result) -> result
    sandbox.SandboxTimedOut ->
      Error("hook timed out in " <> string.join(scope, " > "))
    sandbox.SandboxCrashed(reason) ->
      Error("hook crashed in " <> string.join(scope, " > ") <> ": " <> reason)
  }
}

fn run_runner_hook_teardown(
  config: ParallelConfig,
  scope: List(String),
  info: TestInfo,
  context: context,
  hook: fn(TestInfo, context) -> Result(Nil, String),
) -> Result(Nil, String) {
  let ParallelConfig(default_timeout_ms: default_timeout_ms, max_concurrency: _) =
    config
  let sandbox_config =
    sandbox.SandboxConfig(
      timeout_ms: default_timeout_ms,
      show_crash_reports: False,
    )

  case sandbox.run_isolated(sandbox_config, fn() { hook(info, context) }) {
    sandbox.SandboxCompleted(result) -> result
    sandbox.SandboxTimedOut ->
      Error("hook timed out in " <> string.join(scope, " > "))
    sandbox.SandboxCrashed(reason) ->
      Error("hook crashed in " <> string.join(scope, " > ") <> ": " <> reason)
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

fn run_in_sandbox(
  config: ParallelConfig,
  timeout_override: Option(Int),
  test_function: fn() -> AssertionResult,
) -> AssertionResult {
  let ParallelConfig(default_timeout_ms: default_timeout_ms, max_concurrency: _) =
    config
  let timeout = case timeout_override {
    Some(ms) -> ms
    None -> default_timeout_ms
  }
  let sandbox_config =
    sandbox.SandboxConfig(timeout_ms: timeout, show_crash_reports: False)
  case sandbox.run_isolated(sandbox_config, test_function) {
    sandbox.SandboxCompleted(assertion) -> assertion
    sandbox.SandboxTimedOut ->
      AssertionFailed(hook_failure("timeout", "test timed out"))
    sandbox.SandboxCrashed(reason) ->
      AssertionFailed(hook_failure("crash", reason))
  }
}
