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
import dream_test/sandbox.{
  type Owner, type OwnerResult, OwnerCaught, OwnerExited, OwnerReturned,
  OwnerTimedOut,
}
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
  demonitor_process, kill, monitor, new_selector, new_subject, select,
  select_specific_monitor, selector_receive, send, spawn_unlinked,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
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

/// One step of a test. The test process runs the steps in this order:
/// the runner `before_each_test` hooks, the `before_each` hooks, the body,
/// the `after_each` hooks and the runner `after_each_test` hooks.
type TestStep(context) {
  RunnerBeforeEachStep(hook: fn(TestInfo, context) -> Result(context, String))
  BeforeEachStep(hook: Callback(context, Result(context, String)))
  BodyStep
  AfterEachStep(hook: Callback(context, Result(Nil, String)))
  RunnerAfterEachStep(hook: fn(TestInfo, context) -> Result(Nil, String))
}

/// What is known about one test when a step starts.
///
/// `status` is `Passed` until a set-up step or the body fails. While it is
/// `Passed`, set-up steps and the body run; tear-down steps always run.
/// `context` is the context after the last set-up step that returned, so
/// a tear-down step gets the context that it would get after a body that
/// finished.
type TestState(context) {
  TestState(
    context: context,
    status: Status,
    failures_rev: List(AssertionFailure),
    teardown_failures_rev: List(TeardownFailure),
    started_ms: Int,
  )
}

/// What a test process needs: the test, the steps to run from the first
/// one, and the state when the first step starts.
type TestJob(context) {
  TestJob(
    subject: Subject(WorkerMessage(context)),
    index: Int,
    scope: List(String),
    info: TestInfo,
    test_case: TestCase(context),
    first_step: TestStep(context),
    later_steps: List(TestStep(context)),
    state: TestState(context),
    default_timeout_ms: Int,
  )
}

/// A test process that the loop started and that has not finished. The
/// loop knows its current step, the state when that step started, and the
/// deadline of the step. The loop monitors the process, so a process that
/// stops before it finishes still gives a result.
type RunningWorker(context) {
  RunningWorker(
    job: TestJob(context),
    pid: Pid,
    monitor: Monitor,
    step: TestStep(context),
    later_steps: List(TestStep(context)),
    state: TestState(context),
    deadline_ms: Int,
  )
}

/// A message to the loop about one test process. `StepStarted` comes at
/// the start of each step that runs, with the time on the clock of
/// `timing.now_ms`. `WorkerFinished` comes after the last step.
/// `WorkerDown` comes from the monitor of a process that stopped before
/// it finished.
type WorkerMessage(context) {
  StepStarted(
    worker: Pid,
    step: TestStep(context),
    later_steps: List(TestStep(context)),
    state: TestState(context),
    started_ms: Int,
  )
  WorkerFinished(worker: Pid, outcome: TestOutcome)
  WorkerDown(down: Down)
}

/// Why a step did not finish in its test process.
type StepEnd {
  StepTimedOut
  StepExited(reason: String)
}

/// What stays the same while the tests of one group run.
type GroupRun(context) {
  GroupRun(
    config: ParallelConfig,
    subject: Subject(WorkerMessage(context)),
    scope: List(String),
    inherited_tags: List(String),
    context: context,
    runner_before_each_test: List(
      fn(TestInfo, context) -> Result(context, String),
    ),
    runner_after_each_test: List(fn(TestInfo, context) -> Result(Nil, String)),
    before_each_hooks: List(Callback(context, Result(context, String))),
    after_each_hooks: List(Callback(context, Result(Nil, String))),
    progress_output: Option(ProgressOutput),
    total: Int,
    max_concurrency: Int,
  )
}

/// What changes while the tests of one group run: the tests that wait,
/// the test processes that run, the outcomes that wait for the outcomes
/// before them, and the outcomes in declaration order, newest first.
type LoopState(context) {
  LoopState(
    pending: List(#(Int, TestCase(context))),
    running: List(RunningWorker(context)),
    pending_emit: List(IndexedResult),
    emitted_rev: List(TestOutcome),
    next_emit_index: Int,
    completed: Int,
  )
}

/// A group hook with the context that it gets, so that the owner process
/// of the group can run it.
type GroupHookCall(context) {
  SetUpCall(hook: Callback(context, Result(context, String)), context: context)
  TearDownCall(hook: Callback(context, Result(Nil, String)), context: context)
}

/// The owner process of a group, for its `before_all` and `after_all`
/// hooks.
type GroupOwner(context) =
  Owner(GroupHookCall(context), Result(context, String))

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
// Execution (sequential groups, one process per test)
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
      let #(owner, ctx2, failures) =
        run_before_all_chain(
          config,
          group_scope,
          None,
          context,
          hooks.before_all,
        )

      case failures {
        [_, ..] -> {
          // If before_all fails, do not execute any tests in this scope.
          // Instead, mark all tests under this group as SetupFailed and skip
          // their bodies.
          let group_results_rev =
            fail_tests_due_to_before_all(
              group_scope,
              combined_tags,
              tests,
              groups,
              failures,
              [],
            )
          // These tests never ran in a process, so we must still emit
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
            finish_group_scope(
              config,
              group_scope,
              owner,
              ctx2,
              hooks.after_all,
            )

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

        [] -> {
          let combined_before_each =
            list.append(inherited_before_each, hooks.before_each)
          let combined_after_each =
            list.append(hooks.after_each, inherited_after_each)

          let #(group_outcomes_rev, completed_after_tests) =
            run_tests_in_group(
              GroupRun(
                config: config,
                subject: new_subject(),
                scope: group_scope,
                inherited_tags: combined_tags,
                context: ctx2,
                runner_before_each_test: runner_before_each_test,
                runner_after_each_test: runner_after_each_test,
                before_each_hooks: combined_before_each,
                after_each_hooks: combined_after_each,
                progress_output: progress_output,
                total: total,
                max_concurrency: int.max(config.max_concurrency, 1),
              ),
              tests,
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
            finish_group_scope(
              config,
              group_scope,
              owner,
              ctx2,
              hooks.after_all,
            )

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
  failures: List(AssertionFailure),
  acc_rev: List(TestResult),
) -> List(TestResult) {
  let after_tests =
    fail_test_nodes(scope, inherited_tags, tests, failures, acc_rev)
  fail_group_nodes(scope, inherited_tags, groups, failures, after_tests)
}

fn fail_test_nodes(
  scope: List(String),
  inherited_tags: List(String),
  test_cases: List(TestCase(context)),
  failures: List(AssertionFailure),
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
          failures: failures,
          kind: test_case.kind,
        )
      fail_test_nodes(scope, inherited_tags, rest, failures, [result, ..acc_rev])
    }
  }
}

fn fail_group_nodes(
  scope: List(String),
  inherited_tags: List(String),
  nodes: List(Node(context)),
  failures: List(AssertionFailure),
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
          failures,
          acc_rev,
        )
      fail_group_nodes(scope, inherited_tags, rest, failures, next)
    }
    [_other, ..rest] ->
      fail_group_nodes(scope, inherited_tags, rest, failures, acc_rev)
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
  case children {
    [] -> #(hooks, list.reverse(tests_rev), list.reverse(groups_rev))
    [child, ..rest] ->
      case child {
        BeforeAll(run) ->
          collect_children(
            rest,
            GroupHooks(
              ..hooks,
              before_all: list.append(hooks.before_all, [run]),
            ),
            tests_rev,
            groups_rev,
          )
        BeforeEach(run) ->
          collect_children(
            rest,
            GroupHooks(
              ..hooks,
              before_each: list.append(hooks.before_each, [run]),
            ),
            tests_rev,
            groups_rev,
          )
        AfterEach(run) ->
          collect_children(
            rest,
            GroupHooks(
              ..hooks,
              after_each: list.append(hooks.after_each, [run]),
            ),
            tests_rev,
            groups_rev,
          )
        AfterAll(run) ->
          collect_children(
            rest,
            GroupHooks(..hooks, after_all: list.append(hooks.after_all, [run])),
            tests_rev,
            groups_rev,
          )
        Test(name, tags, kind, run, timeout_ms, source) ->
          collect_children(
            rest,
            hooks,
            [TestCase(name, tags, kind, run, timeout_ms, source), ..tests_rev],
            groups_rev,
          )
        Group(..) ->
          collect_children(rest, hooks, tests_rev, [child, ..groups_rev])
      }
  }
}

// =============================================================================
// The owner process of a group
// =============================================================================

/// Run a group hook in the owner process of the group. A tear-down hook
/// gives back the context that it got, so both kinds of hook have one
/// result type.
fn run_group_hook(call: GroupHookCall(context)) -> Result(context, String) {
  case call {
    SetUpCall(hook: hook, context: context) -> types.call(hook, context)
    TearDownCall(hook: hook, context: context) ->
      types.call(hook, context)
      |> result.replace(context)
  }
}

/// Run the `before_all` hooks of a group in the owner process of the
/// group, and stop at the first failure. The first hook starts the owner.
/// Each hook gets the default timeout.
///
/// Gives the owner (`None` when no owner is alive), the context after the
/// last hook that returned, and the failure (an empty list when every
/// hook returned).
fn run_before_all_chain(
  config: ParallelConfig,
  scope: List(String),
  owner: Option(GroupOwner(context)),
  context: context,
  hooks: List(Callback(context, Result(context, String))),
) -> #(Option(GroupOwner(context)), context, List(AssertionFailure)) {
  case hooks {
    [] -> #(owner, context, [])
    [hook, ..rest] ->
      before_all_result(
        config,
        scope,
        context,
        rest,
        sandbox.run_in_owner(
          owner,
          config.default_timeout_ms,
          run_group_hook,
          SetUpCall(hook: hook, context: context),
        ),
      )
  }
}

fn before_all_result(
  config: ParallelConfig,
  scope: List(String),
  context: context,
  rest: List(Callback(context, Result(context, String))),
  owner_result: OwnerResult(GroupHookCall(context), Result(context, String)),
) -> #(Option(GroupOwner(context)), context, List(AssertionFailure)) {
  case owner_result {
    OwnerReturned(owner: owner, value: Ok(next)) ->
      run_before_all_chain(config, scope, Some(owner), next, rest)
    OwnerReturned(owner: owner, value: Error(message)) -> #(
      Some(owner),
      context,
      [hook_failure("before_all", message)],
    )
    OwnerCaught(owner: owner, reason: reason) -> #(Some(owner), context, [
      hook_failure("before_all", hook_crash_message(scope, reason)),
    ])
    OwnerTimedOut -> #(None, context, [
      hook_failure("before_all", hook_timeout_message(scope)),
    ])
    OwnerExited(reason: reason) -> #(None, context, [
      hook_failure("before_all", hook_crash_message(scope, reason)),
    ])
  }
}

/// End the scope of a group: report an owner that stopped while the tests
/// ran, run every `after_all` hook (in the owner while it is alive, else
/// in a new owner), then stop the owner. Gives the tear-down failures
/// newest first.
fn finish_group_scope(
  config: ParallelConfig,
  scope: List(String),
  owner: Option(GroupOwner(context)),
  context: context,
  hooks: List(Callback(context, Result(Nil, String))),
) -> List(TeardownFailure) {
  let #(checked_owner, exit_failures_rev) = check_group_owner(scope, owner)
  let #(last_owner, failures_rev) =
    run_after_all_chain(
      config,
      scope,
      checked_owner,
      context,
      hooks,
      exit_failures_rev,
    )
  let _stopped = option.map(last_owner, sandbox.stop_owner)
  failures_rev
}

fn check_group_owner(
  scope: List(String),
  owner: Option(GroupOwner(context)),
) -> #(Option(GroupOwner(context)), List(TeardownFailure)) {
  case owner {
    None -> #(None, [])
    Some(owner) -> group_owner_check_result(scope, sandbox.check_owner(owner))
  }
}

fn group_owner_check_result(
  scope: List(String),
  checked: Result(GroupOwner(context), String),
) -> #(Option(GroupOwner(context)), List(TeardownFailure)) {
  case checked {
    Ok(owner) -> #(Some(owner), [])
    Error(reason) -> #(None, [
      TeardownFailure(
        hook: AfterAllHook,
        scope: scope,
        message: "before_all process exited in "
          <> string.join(scope, " > ")
          <> ": "
          <> reason,
      ),
    ])
  }
}

/// Run every `after_all` hook of a group, also after one fails, and give
/// the failures newest first, in front of `failures_rev`. Each hook gets
/// the default timeout. After a timeout or an exit of the owner, the next
/// hook runs in a new owner.
fn run_after_all_chain(
  config: ParallelConfig,
  scope: List(String),
  owner: Option(GroupOwner(context)),
  context: context,
  hooks: List(Callback(context, Result(Nil, String))),
  failures_rev: List(TeardownFailure),
) -> #(Option(GroupOwner(context)), List(TeardownFailure)) {
  case hooks {
    [] -> #(owner, failures_rev)
    [hook, ..rest] -> {
      let #(next_owner, next_failures_rev) =
        after_all_result(
          scope,
          sandbox.run_in_owner(
            owner,
            config.default_timeout_ms,
            run_group_hook,
            TearDownCall(hook: hook, context: context),
          ),
          failures_rev,
        )
      run_after_all_chain(
        config,
        scope,
        next_owner,
        context,
        rest,
        next_failures_rev,
      )
    }
  }
}

fn after_all_result(
  scope: List(String),
  owner_result: OwnerResult(GroupHookCall(context), Result(context, String)),
  failures_rev: List(TeardownFailure),
) -> #(Option(GroupOwner(context)), List(TeardownFailure)) {
  case owner_result {
    OwnerReturned(owner: owner, value: Ok(_context)) -> #(
      Some(owner),
      failures_rev,
    )
    OwnerReturned(owner: owner, value: Error(message)) -> #(
      Some(owner),
      add_teardown_failure(AfterAllHook, scope, message, failures_rev),
    )
    OwnerCaught(owner: owner, reason: reason) -> #(
      Some(owner),
      add_teardown_failure(
        AfterAllHook,
        scope,
        hook_crash_message(scope, reason),
        failures_rev,
      ),
    )
    OwnerTimedOut -> #(
      None,
      add_teardown_failure(
        AfterAllHook,
        scope,
        hook_timeout_message(scope),
        failures_rev,
      ),
    )
    OwnerExited(reason: reason) -> #(
      None,
      add_teardown_failure(
        AfterAllHook,
        scope,
        hook_crash_message(scope, reason),
        failures_rev,
      ),
    )
  }
}

/// Put a failure of a tear-down hook in front of `failures_rev`.
fn add_teardown_failure(
  hook: TeardownHook,
  scope: List(String),
  message: String,
  failures_rev: List(TeardownFailure),
) -> List(TeardownFailure) {
  [TeardownFailure(hook: hook, scope: scope, message: message), ..failures_rev]
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

// =============================================================================
// The tests of a group: one process per test
// =============================================================================

/// Run the tests of a group, at most `max_concurrency` at a time, each in
/// its own process. Gives the outcomes in declaration order, newest first,
/// and the new count of completed tests.
fn run_tests_in_group(
  group: GroupRun(context),
  tests: List(TestCase(context)),
  completed: Int,
) -> #(List(TestOutcome), Int) {
  run_loop(
    group,
    LoopState(
      pending: index_tests(tests, 0, []),
      running: [],
      pending_emit: [],
      emitted_rev: [],
      next_emit_index: 0,
      completed: completed,
    ),
  )
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

/// Start tests up to the limit, then wait for the next event, until no
/// test waits and no test process runs. `max_concurrency` is at least 1,
/// so no process runs only when no test waits.
fn run_loop(
  group: GroupRun(context),
  state: LoopState(context),
) -> #(List(TestOutcome), Int) {
  let started = start_tests_up_to_limit(group, state, timing.now_ms())
  case started.running {
    [] -> #(started.emitted_rev, started.completed)
    [first, ..] ->
      run_loop(group, emit_ready(wait_for_event(group, started, first)))
  }
}

/// Move the outcomes that are next in declaration order from
/// `pending_emit` to `emitted_rev`.
fn emit_ready(state: LoopState(context)) -> LoopState(context) {
  case take_indexed_result(state.next_emit_index, state.pending_emit, []) {
    #(None, _) -> state
    #(Some(IndexedResult(_, outcome)), remaining) ->
      emit_ready(
        LoopState(
          ..state,
          pending_emit: remaining,
          emitted_rev: [outcome, ..state.emitted_rev],
          next_emit_index: state.next_emit_index + 1,
        ),
      )
  }
}

fn take_indexed_result(
  index: Int,
  items: List(IndexedResult),
  acc_rev: List(IndexedResult),
) -> #(Option(IndexedResult), List(IndexedResult)) {
  case items {
    [] -> #(None, list.reverse(acc_rev))
    [item, ..rest] if item.index == index -> #(
      Some(item),
      list.append(list.reverse(acc_rev), rest),
    )
    [item, ..rest] -> take_indexed_result(index, rest, [item, ..acc_rev])
  }
}

fn start_tests_up_to_limit(
  group: GroupRun(context),
  state: LoopState(context),
  now: Int,
) -> LoopState(context) {
  case state.pending, list.length(state.running) < group.max_concurrency {
    [#(index, test_case), ..rest], True ->
      start_tests_up_to_limit(
        group,
        LoopState(..state, pending: rest, running: [
          spawn_test_process(new_test_job(group, index, test_case, now), now),
          ..state.running
        ]),
        now,
      )
    _, _ -> state
  }
}

/// The job of a new test: all its steps, from the first one.
fn new_test_job(
  group: GroupRun(context),
  index: Int,
  test_case: TestCase(context),
  now: Int,
) -> TestJob(context) {
  let info =
    types.TestInfo(
      name: test_case.name,
      groups: group.scope,
      tags: list.append(group.inherited_tags, test_case.tags),
      kind: test_case.kind,
      source: test_case.source,
    )
  let set_up_steps =
    list.append(
      list.map(group.runner_before_each_test, RunnerBeforeEachStep),
      list.map(group.before_each_hooks, BeforeEachStep),
    )
  let tear_down_steps =
    list.append(
      list.map(group.after_each_hooks, AfterEachStep),
      list.map(group.runner_after_each_test, RunnerAfterEachStep),
    )
  let #(first_step, later_steps) = case set_up_steps {
    [] -> #(BodyStep, tear_down_steps)
    [first, ..rest] -> #(
      first,
      list.flatten([rest, [BodyStep], tear_down_steps]),
    )
  }
  TestJob(
    subject: group.subject,
    index: index,
    scope: group.scope,
    info: info,
    test_case: test_case,
    first_step: first_step,
    later_steps: later_steps,
    state: TestState(
      context: group.context,
      status: Passed,
      failures_rev: [],
      teardown_failures_rev: [],
      started_ms: now,
    ),
    default_timeout_ms: group.config.default_timeout_ms,
  )
}

/// Start a process for a job and monitor it. The deadline of its first
/// step counts from `now`.
fn spawn_test_process(
  job: TestJob(context),
  now: Int,
) -> RunningWorker(context) {
  let pid = spawn_unlinked(fn() { run_test_process(job) })
  RunningWorker(
    job: job,
    pid: pid,
    monitor: monitor(pid),
    step: job.first_step,
    later_steps: job.later_steps,
    state: job.state,
    deadline_ms: now + step_timeout(job, job.first_step),
  )
}

/// The timeout of a step: the timeout of the test for the body, and the
/// default timeout for a hook.
fn step_timeout(job: TestJob(context), step: TestStep(context)) -> Int {
  case step {
    BodyStep -> option.unwrap(job.test_case.timeout_ms, job.default_timeout_ms)
    _ -> job.default_timeout_ms
  }
}

/// Wait for the next message from a test process, until the earliest
/// deadline of a step. A message that is already in the mailbox comes
/// first, so a process that finished in time is never taken as late.
fn wait_for_event(
  group: GroupRun(context),
  state: LoopState(context),
  first: RunningWorker(context),
) -> LoopState(context) {
  let deadline = list.fold(state.running, first.deadline_ms, earliest_deadline)
  let selector =
    new_selector()
    |> select(group.subject)
    |> select_worker_monitors(state.running)
  case selector_receive(selector, int.max(deadline - timing.now_ms(), 0)) {
    Ok(StepStarted(
      worker: worker,
      step: step,
      later_steps: later_steps,
      state: step_state,
      started_ms: started_ms,
    )) ->
      LoopState(
        ..state,
        running: record_step(
          state.running,
          StepStarted(
            worker: worker,
            step: step,
            later_steps: later_steps,
            state: step_state,
            started_ms: started_ms,
          ),
          [],
        ),
      )
    Ok(WorkerFinished(worker: worker, outcome: outcome)) -> {
      let #(running, results) =
        remove_finished_worker(state.running, worker, outcome, [], [])
      add_results(group, LoopState(..state, running: running), results)
    }
    Ok(WorkerDown(down: down)) -> {
      let #(running, results) = remove_down_worker(state.running, down, [], [])
      add_results(group, LoopState(..state, running: running), results)
    }
    Error(Nil) -> {
      let #(running, results) =
        expire_workers(state.running, timing.now_ms(), [], [])
      add_results(group, LoopState(..state, running: running), results)
    }
  }
}

fn earliest_deadline(deadline: Int, worker: RunningWorker(context)) -> Int {
  int.min(deadline, worker.deadline_ms)
}

/// Select the down message of each running process. Only these monitors
/// are selected, so other down messages of the calling process stay in
/// its mailbox.
fn select_worker_monitors(
  selector: Selector(WorkerMessage(context)),
  running: List(RunningWorker(context)),
) -> Selector(WorkerMessage(context)) {
  case running {
    [] -> selector
    [worker, ..rest] ->
      selector
      |> select_specific_monitor(worker.monitor, WorkerDown)
      |> select_worker_monitors(rest)
  }
}

/// Record the step that a process started: its state and the deadline of
/// the step, from the time that the process gave.
fn record_step(
  running: List(RunningWorker(context)),
  message: WorkerMessage(context),
  kept_rev: List(RunningWorker(context)),
) -> List(RunningWorker(context)) {
  case running, message {
    [], _ -> list.reverse(kept_rev)
    [worker, ..rest],
      StepStarted(
        worker: pid,
        step: step,
        later_steps: later_steps,
        state: state,
        started_ms: started_ms,
      )
      if worker.pid == pid
    ->
      record_step(rest, message, [
        RunningWorker(
          ..worker,
          step: step,
          later_steps: later_steps,
          state: state,
          deadline_ms: started_ms + step_timeout(worker.job, step),
        ),
        ..kept_rev
      ])
    [worker, ..rest], _ -> record_step(rest, message, [worker, ..kept_rev])
  }
}

/// Remove the process that sent its outcome. A process sends its outcome
/// before it exits, so the outcome comes before the down message;
/// `demonitor_process` also removes a down message that is already in the
/// mailbox.
fn remove_finished_worker(
  running: List(RunningWorker(context)),
  pid: Pid,
  outcome: TestOutcome,
  kept_rev: List(RunningWorker(context)),
  results: List(IndexedResult),
) -> #(List(RunningWorker(context)), List(IndexedResult)) {
  case running {
    [] -> #(list.reverse(kept_rev), results)
    [worker, ..rest] if worker.pid == pid -> {
      demonitor_process(worker.monitor)
      remove_finished_worker(rest, pid, outcome, kept_rev, [
        IndexedResult(index: worker.job.index, outcome: outcome),
        ..results
      ])
    }
    [worker, ..rest] ->
      remove_finished_worker(rest, pid, outcome, [worker, ..kept_rev], results)
  }
}

/// Handle the process of a monitor that sent a down message: the process
/// stopped in its current step.
fn remove_down_worker(
  running: List(RunningWorker(context)),
  down: Down,
  kept_rev: List(RunningWorker(context)),
  results: List(IndexedResult),
) -> #(List(RunningWorker(context)), List(IndexedResult)) {
  case running {
    [] -> #(list.reverse(kept_rev), results)
    [worker, ..rest] if worker.monitor == down.monitor -> {
      let #(next_kept_rev, next_results) =
        after_step_end(
          worker,
          StepExited(sandbox.format_exit_reason(down.reason)),
          kept_rev,
          results,
        )
      remove_down_worker(rest, down, next_kept_rev, next_results)
    }
    [worker, ..rest] ->
      remove_down_worker(rest, down, [worker, ..kept_rev], results)
  }
}

/// Kill each process whose step is past its deadline.
fn expire_workers(
  running: List(RunningWorker(context)),
  now: Int,
  kept_rev: List(RunningWorker(context)),
  results: List(IndexedResult),
) -> #(List(RunningWorker(context)), List(IndexedResult)) {
  case running {
    [] -> #(list.reverse(kept_rev), results)
    [worker, ..rest] if worker.deadline_ms <= now -> {
      kill(worker.pid)
      demonitor_process(worker.monitor)
      let #(next_kept_rev, next_results) =
        after_step_end(worker, StepTimedOut, kept_rev, results)
      expire_workers(rest, now, next_kept_rev, next_results)
    }
    [worker, ..rest] -> expire_workers(rest, now, [worker, ..kept_rev], results)
  }
}

/// After a step did not finish: record the failure of the step, then run
/// the tear-down steps that did not run yet in a new process, with the
/// context that they would get after the body. With no such step, the
/// test has its outcome.
fn after_step_end(
  worker: RunningWorker(context),
  end: StepEnd,
  kept_rev: List(RunningWorker(context)),
  results: List(IndexedResult),
) -> #(List(RunningWorker(context)), List(IndexedResult)) {
  let state = fail_step(worker.job, worker.step, worker.state, end)
  case list.filter(worker.later_steps, is_teardown_step) {
    [] -> #(kept_rev, [
      IndexedResult(
        index: worker.job.index,
        outcome: test_outcome(worker.job, state),
      ),
      ..results
    ])
    [first, ..rest] -> {
      let job =
        TestJob(
          ..worker.job,
          first_step: first,
          later_steps: rest,
          state: state,
        )
      #([spawn_test_process(job, timing.now_ms()), ..kept_rev], results)
    }
  }
}

/// Emit progress for new results and keep them until their turn.
fn add_results(
  group: GroupRun(context),
  state: LoopState(context),
  results: List(IndexedResult),
) -> LoopState(context) {
  LoopState(
    ..state,
    pending_emit: list.append(results, state.pending_emit),
    completed: emit_test_finished_progress_results(
      group.progress_output,
      state.completed,
      group.total,
      list.map(results, indexed_result_value),
    ),
  )
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

// =============================================================================
// The test process
// =============================================================================

/// The body of a test process: run the steps of the job, then send the
/// outcome. Before each step that runs, the process tells the loop the
/// step and the state, so the loop can end the test if the process stops.
fn run_test_process(job: TestJob(context)) -> Nil {
  let state = run_steps(job, [job.first_step, ..job.later_steps], job.state)
  send(
    job.subject,
    WorkerFinished(worker: process.self(), outcome: test_outcome(job, state)),
  )
}

fn run_steps(
  job: TestJob(context),
  steps: List(TestStep(context)),
  state: TestState(context),
) -> TestState(context) {
  case steps {
    [] -> state
    [step, ..later_steps] ->
      run_steps(
        job,
        later_steps,
        run_step_when_due(job, step, later_steps, state),
      )
  }
}

/// Run a step when it is due: a tear-down step always, a set-up step and
/// the body only while nothing failed.
fn run_step_when_due(
  job: TestJob(context),
  step: TestStep(context),
  later_steps: List(TestStep(context)),
  state: TestState(context),
) -> TestState(context) {
  case is_teardown_step(step) || state.status == Passed {
    False -> state
    True -> {
      send(
        job.subject,
        StepStarted(
          worker: process.self(),
          step: step,
          later_steps: later_steps,
          state: state,
          started_ms: timing.now_ms(),
        ),
      )
      run_step(job, step, state)
    }
  }
}

fn is_teardown_step(step: TestStep(context)) -> Bool {
  case step {
    AfterEachStep(_) | RunnerAfterEachStep(_) -> True
    RunnerBeforeEachStep(_) | BeforeEachStep(_) | BodyStep -> False
  }
}

/// Run one step in the test process. A crash of the step is caught.
fn run_step(
  job: TestJob(context),
  step: TestStep(context),
  state: TestState(context),
) -> TestState(context) {
  case step {
    RunnerBeforeEachStep(hook: hook) ->
      set_up_step_result(
        job,
        state,
        "before_each_test",
        sandbox.run_catching(
          call_runner_hook,
          RunnerHookCall(hook: hook, info: job.info, context: state.context),
        ),
      )
    BeforeEachStep(hook: hook) ->
      set_up_step_result(
        job,
        state,
        "before_each",
        sandbox.run_catching(
          call_hook,
          HookCall(hook: hook, input: state.context),
        ),
      )
    BodyStep ->
      body_result(
        state,
        sandbox.run_catching(
          run_test_body,
          TestBody(run: job.test_case.run, context: state.context),
        ),
      )
    AfterEachStep(hook: hook) ->
      tear_down_step_result(
        job,
        state,
        AfterEachHook,
        sandbox.run_catching(
          call_hook,
          HookCall(hook: hook, input: state.context),
        ),
      )
    RunnerAfterEachStep(hook: hook) ->
      tear_down_step_result(
        job,
        state,
        AfterEachTestHook,
        sandbox.run_catching(
          call_runner_hook,
          RunnerHookCall(hook: hook, info: job.info, context: state.context),
        ),
      )
  }
}

fn set_up_step_result(
  job: TestJob(context),
  state: TestState(context),
  operator: String,
  caught: Result(Result(context, String), String),
) -> TestState(context) {
  case caught {
    Ok(Ok(next)) -> TestState(..state, context: next)
    Ok(Error(message)) -> set_up_failed(state, operator, message)
    Error(reason) ->
      set_up_failed(state, operator, hook_crash_message(job.scope, reason))
  }
}

fn body_result(
  state: TestState(context),
  caught: Result(AssertionResult, String),
) -> TestState(context) {
  case caught {
    Ok(AssertionOk) -> state
    Ok(AssertionFailed(failure)) -> body_ended(state, Failed, failure)
    Ok(AssertionSkipped) -> TestState(..state, status: Skipped)
    Error(reason) -> body_ended(state, Failed, hook_failure("crash", reason))
  }
}

fn tear_down_step_result(
  job: TestJob(context),
  state: TestState(context),
  hook: TeardownHook,
  caught: Result(Result(Nil, String), String),
) -> TestState(context) {
  case caught {
    Ok(Ok(Nil)) -> state
    Ok(Error(message)) -> tear_down_failed(job, state, hook, message)
    Error(reason) ->
      tear_down_failed(job, state, hook, hook_crash_message(job.scope, reason))
  }
}

/// The state after a step that did not finish in its process: it ran past
/// its deadline, or the process stopped.
fn fail_step(
  job: TestJob(context),
  step: TestStep(context),
  state: TestState(context),
  end: StepEnd,
) -> TestState(context) {
  case step, end {
    RunnerBeforeEachStep(_), _ ->
      set_up_failed(state, "before_each_test", step_end_message(job, end))
    BeforeEachStep(_), _ ->
      set_up_failed(state, "before_each", step_end_message(job, end))
    BodyStep, StepTimedOut ->
      body_ended(state, TimedOut, hook_failure("timeout", "test timed out"))
    BodyStep, StepExited(reason: reason) ->
      body_ended(
        state,
        Failed,
        hook_failure(
          "crash",
          "worker crashed in "
            <> string.join(job.scope, " > ")
            <> ": "
            <> reason,
        ),
      )
    AfterEachStep(_), _ ->
      tear_down_failed(job, state, AfterEachHook, step_end_message(job, end))
    RunnerAfterEachStep(_), _ ->
      tear_down_failed(
        job,
        state,
        AfterEachTestHook,
        step_end_message(job, end),
      )
  }
}

/// The message for a hook step that did not finish, in the same words as
/// for a hook that timed out or crashed before.
fn step_end_message(job: TestJob(context), end: StepEnd) -> String {
  case end {
    StepTimedOut -> hook_timeout_message(job.scope)
    StepExited(reason: reason) -> hook_crash_message(job.scope, reason)
  }
}

fn set_up_failed(
  state: TestState(context),
  operator: String,
  message: String,
) -> TestState(context) {
  TestState(..state, status: SetupFailed, failures_rev: [
    hook_failure(operator, message),
    ..state.failures_rev
  ])
}

fn body_ended(
  state: TestState(context),
  status: Status,
  failure: AssertionFailure,
) -> TestState(context) {
  TestState(..state, status: status, failures_rev: [
    failure,
    ..state.failures_rev
  ])
}

fn tear_down_failed(
  job: TestJob(context),
  state: TestState(context),
  hook: TeardownHook,
  message: String,
) -> TestState(context) {
  TestState(
    ..state,
    teardown_failures_rev: add_teardown_failure(
      hook,
      types.full_name(job.scope, job.test_case.name),
      message,
      state.teardown_failures_rev,
    ),
  )
}

/// The outcome of a test from its state after its last step.
fn test_outcome(
  job: TestJob(context),
  state: TestState(context),
) -> TestOutcome {
  TestOutcome(
    result: TestResult(
      name: job.test_case.name,
      groups: job.scope,
      status: state.status,
      duration_ms: timing.now_ms() - state.started_ms,
      tags: job.info.tags,
      failures: list.reverse(state.failures_rev),
      kind: job.test_case.kind,
    ),
    teardown_failures: list.reverse(state.teardown_failures_rev),
  )
}

// =============================================================================
// Hook helpers
// =============================================================================

/// A runner hook with the two arguments it gets, so that it can run as a
/// function of one input.
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

/// A group hook with its input, so that it can run as a function of one
/// input.
type HookCall(input, output) {
  HookCall(hook: Callback(input, output), input: input)
}

fn call_hook(call: HookCall(input, output)) -> output {
  types.call(call.hook, call.input)
}

fn hook_crash_message(scope: List(String), reason: String) -> String {
  "hook crashed in " <> string.join(scope, " > ") <> ": " <> reason
}

fn hook_timeout_message(scope: List(String)) -> String {
  "hook timed out in " <> string.join(scope, " > ")
}

fn hook_failure(operator: String, message: String) -> AssertionFailure {
  AssertionFailure(operator: operator, message: message, payload: None)
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
