//// Unified Tree/Node execution engine (parallel tests, sequential groups).
////
//// This module executes a typed tree, a `types.Tree(context)`. A
//// `dream_test/suite.TestSuite` keeps one or more such trees inside it, and the runner
//// runs it with this module.
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
////     it("can run a tree and return a report of the results", fn() {
////       let tree =
////         types.tree("Suite", Nil, [
////           it("a", fn() { Ok(succeed()) }),
////           it("b", fn() { Ok(succeed()) }),
////         ])
////
////       parallel.run_tree_parallel(parallel.default_config(), tree)
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
  type SetupProcess, type SetupProcessResult, SetupProcessCaught,
  SetupProcessExited, SetupProcessLost, SetupProcessReturned,
  SetupProcessTimedOut,
}
import dream_test/timing
import dream_test/types.{
  type AssertionFailure, type AssertionResult, type Callback, type Node,
  type RunReport, type SetupHook, type Status, type SuiteContext,
  type TeardownFailure, type TeardownHook, type TestInfo, type TestKind,
  type TestResult, type Tree, AfterAll, AfterAllHook, AfterEach, AfterEachHook,
  AfterEachTestHook, AssertionFailed, AssertionFailure, AssertionOk,
  AssertionPending, AssertionSkipped, BeforeAll, BeforeAllHook,
  BeforeAllSuitesHook, BeforeEach, BeforeEachSuiteHook, ContextFromSetup, Failed,
  FixedContext, Group, Passed, Pending, SetupFailed, Skipped, SuiteSetupHook,
  SuiteTeardownHook, TeardownFailure, Test, TestResult, TimedOut, Tree,
  WithInput,
}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{
  type Down, type Monitor, type Pid, type Selector, type Subject,
  demonitor_process, monitor, new_selector, new_subject, select,
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
/// - `max_concurrency`: how many direct tests of one group may run at once
/// - `default_timeout_ms`: default per-test timeout (used when a test doesn’t
///   specify its own timeout)
///
/// ## Fields
///
/// - `max_concurrency`: the most direct tests of one group that run at the
///   same time. The groups run one after the other: first the direct tests
///   of a group, then each child group in the written order. A value below
///   1 counts as 1.
/// - `default_timeout_ms`: timeout used when a test does not set its own timeout
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{have_length, or_fail_with, should, succeed}
/// import dream_test/parallel.{ParallelConfig}
/// import dream_test/types
/// import dream_test/unit.{describe, it}
///
/// pub fn tests() {
///   let config = ParallelConfig(max_concurrency: 2, default_timeout_ms: 1000)
///
///   describe("ParallelConfig", [
///     it("can be constructed to customize execution", fn() {
///       let tree =
///         types.tree("Suite", Nil, [
///           it("a", fn() { Ok(succeed()) }),
///         ])
///
///       parallel.run_tree_parallel(config, tree)
///       |> types.report_tests
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

/// Configuration for `run_tree_parallel_with_reporter`.
///
/// This is an advanced API intended for building custom runners that want to
/// drive a reporter while executing a single tree.
///
/// `outer_setups` are the setups around the suite that keep their
/// resources alive in a process, outermost first: for example the
/// `before_all_suites` setup of the whole run and the `before_each_suite`
/// setup of the suite. Give `[]` when the suite has no such setup.
pub type RunTreeParallelWithReporterConfig(context) {
  RunTreeParallelWithReporterConfig(
    config: ParallelConfig,
    tree: Tree(context),
    progress_reporter: Option(progress.ProgressReporter),
    write: fn(String) -> Nil,
    total: Int,
    completed: Int,
    runner_before_each_test: List(fn(TestInfo) -> Result(Nil, String)),
    runner_after_each_test: List(fn(TestInfo) -> Result(Nil, String)),
    outer_setups: List(OuterSetup),
  )
}

/// Configuration for `run_tree`.
///
/// It holds the same fields as `RunTreeParallelWithReporterConfig`, with the
/// tree in its own fields and one more field, `groups`:
///
/// - `groups`: the names of the groups around the tree, outermost first.
///   Each test result, each `TestInfo` that a runner hook gets and each
///   progress line has them in front of the names of the tree. Give `[]`
///   for a tree that is not inside a group.
/// - `name`, `tags`, `children`: the name, the tags and the children of the
///   top-level group of the tree.
/// - `context`: where the tests get their context, a
///   `types.FixedContext(value)` or a `types.ContextFromSetup(setup,
///   teardown)` (see `types.SuiteContext`).
pub type RunTreeConfig(context) {
  RunTreeConfig(
    config: ParallelConfig,
    groups: List(String),
    name: String,
    tags: List(String),
    children: List(Node(context)),
    context: SuiteContext(context),
    progress_reporter: Option(progress.ProgressReporter),
    write: fn(String) -> Nil,
    total: Int,
    completed: Int,
    runner_before_each_test: List(fn(TestInfo) -> Result(Nil, String)),
    runner_after_each_test: List(fn(TestInfo) -> Result(Nil, String)),
    outer_setups: List(OuterSetup),
  )
}

/// A setup around a suite that keeps its resources alive in a process,
/// for `run_tree_parallel_with_reporter`.
///
/// The executor checks each outer setup before each test and each group
/// starts. After the process of a setup stopped, no test or hook of the
/// suite starts: each test that did not start is `SetupFailed` with the
/// failure `not run: the setup from <setup hook> in "<groups>" stopped
/// (<reason>)`, for example
/// `not run: the setup from before_each_suite in "suite" stopped (<reason>)`,
/// with the operator `<setup hook>`. The executor records the full name of
/// each of these tests in the `not_run` of the outermost stopped setup,
/// after the names that it had already. Tests that started finish, and the
/// `after_all` hooks of the groups that started still run. The executor
/// does not report the stopped setup as a teardown failure: the caller
/// owns the setup, so the caller reports it once, for example as
/// `types.SetupStopped`, and runs its teardown hooks.
///
/// ## Variants
///
/// - `SetupRunning(setup, groups, check_setup_process)`: the process of the setup
///   was alive at the last check. `check_setup_process` checks it again and gives
///   `Ok(Nil)` while it is alive, or `Error(reason)` after it stopped. The
///   executor does not call `check_setup_process` again after it gave `Error`.
///   With `sandbox.SetupProcess`, use `sandbox.check_setup_process`.
/// - `SetupStopped(setup, groups, reason, not_run)`: the process of the
///   setup exited with `reason`. `not_run` is the full name of each test
///   that was not run because of it (see `types.full_name`), in the order
///   of the run. Give `[]` for a setup that no test was skipped for yet.
///
/// `setup` is the setup hook. `groups` is `[]` for the whole run, or the
/// names of the groups that the setup serves, for example `[suite name]`.
pub type OuterSetup {
  SetupRunning(
    setup: SetupHook,
    groups: List(String),
    check_setup_process: fn() -> Result(Nil, String),
  )
  SetupStopped(
    setup: SetupHook,
    groups: List(String),
    reason: String,
    not_run: List(List(String)),
  )
}

/// Result of `run_tree_parallel_with_reporter`.
///
/// This is returned as a semantic type (not a tuple) so callers can use named
/// fields and avoid positional destructuring. A teardown failure is not a
/// test result, so it is in `teardown_failures`, not in `results`.
///
/// `outer_setups` are the setups of the config in the same order, as the
/// executor saw them last. A setup whose process stopped during the run
/// is `SetupStopped`, and its `check_setup_process` will not tell again: use this
/// list, not `check_setup_process`, to learn that the setup stopped.
pub type RunTreeParallelWithReporterResult {
  RunTreeParallelWithReporterResult(
    results: List(TestResult),
    teardown_failures: List(TeardownFailure),
    completed: Int,
    progress_reporter: Option(progress.ProgressReporter),
    outer_setups: List(OuterSetup),
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
    runner_before_each_test: List(fn(TestInfo) -> Result(Nil, String)),
    runner_after_each_test: List(fn(TestInfo) -> Result(Nil, String)),
    node: Node(context),
    progress_output: Option(ProgressOutput),
    total: Int,
    completed: Int,
    collected: Collected,
    /// The setup processes of the scopes around the node.
    setup_processes: SetupProcesses(context),
  )
}

/// What a run has collected so far, newest first: the test results and the
/// teardown failures.
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
  RunnerBeforeEachStep(hook: fn(TestInfo) -> Result(Nil, String))
  BeforeEachStep(hook: Callback(context, Result(context, String)))
  BodyStep
  AfterEachStep(hook: Callback(context, Result(Nil, String)))
  RunnerAfterEachStep(hook: fn(TestInfo) -> Result(Nil, String))
}

/// What is known about one test when a step starts.
///
/// `status` is `Passed` until a setup step or the body fails. While it is
/// `Passed`, setup steps and the body run; teardown steps always run.
/// `context` is the context after the last setup step that returned, so
/// a teardown step gets the context that it would get after a body that
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
/// stops before it finishes still gives a result. `killed` holds the step
/// that ran when the loop killed the process at a deadline: the loop still
/// reads its messages until its down message, so an outcome that the
/// process sent before the kill is not lost.
type RunningWorker(context) {
  RunningWorker(
    job: TestJob(context),
    pid: Pid,
    monitor: Monitor,
    step: TestStep(context),
    later_steps: List(TestStep(context)),
    state: TestState(context),
    deadline_ms: Int,
    killed: Option(KilledStep(context)),
  )
}

/// The step that ran when the loop killed a test process at its deadline,
/// and the steps after it. This step is the step that timed out, also when
/// the process started a later step before the kill reached it.
type KilledStep(context) {
  KilledStep(step: TestStep(context), later_steps: List(TestStep(context)))
}

/// A step that did not finish in its test process: the step, the state
/// that the teardown steps start from, the steps after it that did not
/// finish, and why it did not finish.
type EndedStep(context) {
  EndedStep(
    step: TestStep(context),
    state: TestState(context),
    later_steps: List(TestStep(context)),
    end: StepEnd,
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
    runner_before_each_test: List(fn(TestInfo) -> Result(Nil, String)),
    runner_after_each_test: List(fn(TestInfo) -> Result(Nil, String)),
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
    /// The setup processes of the scopes of the group. A test starts only while
    /// every setup process is alive.
    setup_processes: SetupProcesses(context),
  )
}

/// A group hook with the context that it gets, so that the setup process
/// of the group can run it.
type GroupHookCall(context) {
  /// The setup of a suite (see `types.ContextFromSetup`). Its value is
  /// the context of the suite.
  StartCall(setup: fn() -> Result(context, String))
  SetupCall(hook: Callback(context, Result(context, String)), context: context)
  TeardownCall(hook: Callback(context, Result(Nil, String)), context: context)
}

/// The setup process of a group, for its `before_all` and `after_all`
/// hooks.
type GroupSetupProcess(context) =
  SetupProcess(GroupHookCall(context), Result(context, String))

/// The setup process of a group scope whose `before_all` hooks returned,
/// as the tests of the scope see it.
type ScopeSetupProcess(context) {
  /// The setup process was alive at the last check.
  SetupProcessAlive(
    scope: List(String),
    setup_process: GroupSetupProcess(context),
    setup: SetupHook,
  )
  /// The setup process stopped with `reason`. The tests of the scope that have not
  /// started do not run, and its `after_all` hooks run in a new setup process.
  /// `not_run` is the full name of each test that it did not run, in the
  /// order of the run.
  SetupProcessGone(
    scope: List(String),
    reason: String,
    not_run: List(List(String)),
    setup: SetupHook,
  )
}

/// The names that the reports give to the setup and the teardown of a
/// group scope: the `before_all` and `after_all` hooks of a group, or the
/// setup and the teardown of a suite (see `types.ContextFromSetup`).
/// `setup_text` and `teardown_text` start the text of a crash or a
/// timeout, for example `hook crashed in <groups>: <reason>`.
type ScopeHooks {
  ScopeHooks(
    setup: SetupHook,
    teardown: TeardownHook,
    setup_text: String,
    teardown_text: String,
  )
}

/// The names for the scope whose setup is `setup`.
fn scope_hooks(setup: SetupHook) -> ScopeHooks {
  case setup {
    SuiteSetupHook ->
      ScopeHooks(
        setup: SuiteSetupHook,
        teardown: SuiteTeardownHook,
        setup_text: "the suite setup",
        teardown_text: "the suite teardown",
      )
    BeforeAllHook | BeforeEachSuiteHook | BeforeAllSuitesHook ->
      ScopeHooks(
        setup: BeforeAllHook,
        teardown: AfterAllHook,
        setup_text: "hook",
        teardown_text: "hook",
      )
  }
}

/// The setup processes of the scopes around a test: the outer setups of the
/// suite, then the group scopes, each list outermost first.
type SetupProcesses(context) {
  SetupProcesses(
    outer: List(OuterSetup),
    groups: List(ScopeSetupProcess(context)),
  )
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
///     it("can run a tree and return a report of the results", fn() {
///       let tree =
///         types.tree("Suite", Nil, [
///           it("a", fn() { Ok(succeed()) }),
///           it("b", fn() { Ok(succeed()) }),
///         ])
///
///       parallel.run_tree_parallel(parallel.default_config(), tree)
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

/// Run a single tree and return results.
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
///     it("can run a tree and return a report of the results", fn() {
///       let tree =
///         types.tree("Suite", Nil, [
///           it("a", fn() { Ok(succeed()) }),
///           it("b", fn() { Ok(succeed()) }),
///         ])
///
///       parallel.run_tree_parallel(parallel.default_config(), tree)
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
/// - `tree`: the tree to execute
///
/// ## Returns
///
/// A `types.RunReport` with the `TestResult` of each test, in deterministic
/// (declaration) order, and the `after_each` and `after_all` hooks that
/// failed, in the order that they ran.
pub fn run_tree_parallel(
  config config: ParallelConfig,
  tree tree: Tree(context),
) -> RunReport {
  let Tree(seed: seed, name: name, tags: tags, children: children) = tree
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
      setup_processes: SetupProcesses(outer: [], groups: []),
    )

  let #(collected, _completed, _setup_processes) = execute_node(executor_input)
  types.run_report(
    tests: list.reverse(collected.results_rev),
    teardown_failures: list.reverse(collected.teardown_failures_rev),
    reporter_crashes: [],
  )
}

/// Run a single tree while driving a reporter.
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
/// import dream_test/types.{type Tree}
/// import dream_test/unit.{it}
/// import gleam/option.{None}
/// 
/// pub fn tree() -> Tree(Nil) {
///   types.tree("suite", Nil, [
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
///     parallel.run_tree_parallel_with_reporter(
///       parallel.RunTreeParallelWithReporterConfig(
///         config: parallel.default_config(),
///         tree: tree(),
///         progress_reporter: None,
///         write: ignore,
///         total: total,
///         completed: completed,
///         runner_before_each_test: [],
///         runner_after_each_test: [],
///         outer_setups: [],
///       ),
///     )
///   let parallel.RunTreeParallelWithReporterResult(
///     results: results,
///     teardown_failures: _teardown_failures,
///     completed: _completed_after_suite,
///     progress_reporter: _progress_reporter,
///     outer_setups: _outer_setups,
///   ) = parallel_result
///   results
/// }
/// ```
///
/// ## Parameters
///
/// - `config`: execution settings for this suite
/// - `tree`: the tree to execute
/// - `progress_reporter`: optional progress reporter state (typically `Some(progress.new())`)
/// - `write`: output sink for any progress output (typically `io.print`)
/// - `total`: total number of tests in the overall run (across all suites)
/// - `completed`: number of tests already completed before this suite starts
/// - `runner_before_each_test` and `runner_after_each_test`: hooks that run
///   around each test, outside its `before_each` and `after_each` hooks.
///   They get the `TestInfo` of the test, not its context
/// - `outer_setups`: the setups around the suite that keep their
///   resources alive in a process, outermost first. After the process of
///   one stopped, no test or hook of the suite starts (see `OuterSetup`)
///
/// ## Returns
///
/// A `RunTreeParallelWithReporterResult` containing:
/// - `results`: this suite’s results, in deterministic (declaration) order
/// - `teardown_failures`: this suite’s `after_each`, `after_each_test` and
///   `after_all` hooks that failed, in the order that they ran
/// - `completed`: updated completed count after driving `TestFinished` events
/// - `progress_reporter`: progress reporter state (unchanged for the built-in progress reporter)
/// - `outer_setups`: the outer setups as the executor saw them last; a
///   setup whose process stopped is `SetupStopped`
pub fn run_tree_parallel_with_reporter(
  config config: RunTreeParallelWithReporterConfig(context),
) -> RunTreeParallelWithReporterResult {
  let Tree(seed: seed, name: name, tags: tags, children: children) = config.tree
  run_tree(RunTreeConfig(
    config: config.config,
    groups: [],
    name: name,
    tags: tags,
    children: children,
    context: FixedContext(seed),
    progress_reporter: config.progress_reporter,
    write: config.write,
    total: config.total,
    completed: config.completed,
    runner_before_each_test: config.runner_before_each_test,
    runner_after_each_test: config.runner_after_each_test,
    outer_setups: config.outer_setups,
  ))
}

/// Run a typed tree inside the groups `groups`, while driving a reporter.
///
/// This is what `run_tree_parallel_with_reporter` does, for a tree that
/// can be inside groups. `dream_test/suite` uses it to run each tree of a
/// suite: the trees of a suite that `suite.group` put in a group run with
/// that group in `groups`.
///
/// ## Parameters
///
/// - `config`: the tree, where it is, and the run around it (see
///   `RunTreeConfig`)
///
/// ## Returns
///
/// A `RunTreeParallelWithReporterResult`, as
/// `run_tree_parallel_with_reporter` gives it.
///
/// ## Example
///
/// ```gleam
/// parallel.run_tree(parallel.RunTreeConfig(
///   config: parallel.default_config(),
///   groups: ["all"],
///   name: "suite",
///   tags: [],
///   children: [unit.it("passes", passes)],
///   context: types.FixedContext(Nil),
///   progress_reporter: None,
///   write: ignore,
///   total: 1,
///   completed: 0,
///   runner_before_each_test: [],
///   runner_after_each_test: [],
///   outer_setups: [],
/// ))
/// ```
pub fn run_tree(
  config config: RunTreeConfig(context),
) -> RunTreeParallelWithReporterResult {
  let setup_processes =
    refresh_setup_processes(
      SetupProcesses(outer: config.outer_setups, groups: []),
    )
  case config.context, stopped_setup(setup_processes) {
    FixedContext(value: value), _ ->
      tree_result(
        config,
        execute_or_fail_group(tree_input(config, value, setup_processes)),
      )
    ContextFromSetup(..), Some(stopped) ->
      tree_result(
        config,
        fail_after_stop(
          config.groups,
          [],
          tree_node(config),
          stopped,
          progress_output(config.progress_reporter, config.write),
          config.completed,
          config.total,
          empty_collected(),
        ),
      )
    ContextFromSetup(setup: setup, teardown: teardown), None ->
      start_setup(config, setup_processes, setup, teardown)
  }
}

/// The top-level group of the tree of a suite.
fn tree_node(config: RunTreeConfig(context)) -> Node(context) {
  Group(name: config.name, tags: config.tags, children: config.children)
}

/// The executor input for the tree of a suite with its context.
fn tree_input(
  config: RunTreeConfig(context),
  context: context,
  setup_processes: SetupProcesses(context),
) -> ExecuteNodeConfig(context) {
  ExecuteNodeConfig(
    config: config.config,
    scope: config.groups,
    inherited_tags: [],
    context: context,
    inherited_before_each: [],
    inherited_after_each: [],
    runner_before_each_test: config.runner_before_each_test,
    runner_after_each_test: config.runner_after_each_test,
    node: tree_node(config),
    progress_output: progress_output(config.progress_reporter, config.write),
    total: config.total,
    completed: config.completed,
    collected: empty_collected(),
    setup_processes: setup_processes,
  )
}

fn tree_result(
  config: RunTreeConfig(context),
  ran: #(Collected, Int, SetupProcesses(context)),
) -> RunTreeParallelWithReporterResult {
  let #(collected, completed, setup_processes) = ran
  RunTreeParallelWithReporterResult(
    results: list.reverse(collected.results_rev),
    teardown_failures: list.reverse(collected.teardown_failures_rev),
    completed: completed,
    progress_reporter: config.progress_reporter,
    outer_setups: setup_processes.outer,
  )
}

/// Run the setup of a suite in a new setup process, then the tests with
/// its value, then the teardown in the same setup process.
fn start_setup(
  config: RunTreeConfig(context),
  setup_processes: SetupProcesses(context),
  setup: fn() -> Result(context, String),
  teardown: fn(context) -> Result(Nil, String),
) -> RunTreeParallelWithReporterResult {
  let scope = list.append(config.groups, [config.name])
  case
    sandbox.run_in_setup_process(
      None,
      config.config.default_timeout_ms,
      run_group_hook,
      StartCall(setup: setup),
    )
  {
    SetupProcessReturned(setup_process: setup_process, value: Ok(context)) ->
      run_after_setup(
        config,
        setup_processes,
        SetupProcessAlive(
          scope: scope,
          setup_process: setup_process,
          setup: SuiteSetupHook,
        ),
        context,
        teardown,
      )
    SetupProcessReturned(setup_process: setup_process, value: Error(message)) -> {
      sandbox.stop_setup_process(setup_process)
      suite_setup_failed(config, setup_processes, failed_setup(message))
    }
    SetupProcessCaught(setup_process: setup_process, reason: reason) -> {
      sandbox.stop_setup_process(setup_process)
      suite_setup_failed(
        config,
        setup_processes,
        failed_setup(scope_crash_message(
          scope_hooks(SuiteSetupHook).setup_text,
          scope,
          reason,
        )),
      )
    }
    SetupProcessTimedOut ->
      suite_setup_failed(
        config,
        setup_processes,
        failed_setup(scope_timeout_message(
          scope_hooks(SuiteSetupHook).setup_text,
          scope,
        )),
      )
    SetupProcessExited(reason: reason) | SetupProcessLost(reason: reason) ->
      suite_setup_stopped(config, setup_processes, scope, reason)
  }
}

/// The failure of each test of a suite whose setup failed.
fn failed_setup(message: String) -> AssertionFailure {
  hook_failure(types.setup_hook_name(SuiteSetupHook), message)
}

fn run_after_setup(
  config: RunTreeConfig(context),
  setup_processes: SetupProcesses(context),
  own: ScopeSetupProcess(context),
  context: context,
  teardown: fn(context) -> Result(Nil, String),
) -> RunTreeParallelWithReporterResult {
  let #(collected, completed, setup_processes_after) =
    execute_or_fail_group(tree_input(
      config,
      context,
      SetupProcesses(..setup_processes, groups: [own]),
    ))
  let teardown_failures_rev =
    finish_group_scope(
      config.config,
      GroupScope(groups: own.scope, hooks: scope_hooks(SuiteSetupHook)),
      option.from_result(list.first(setup_processes_after.groups)),
      context,
      [WithInput(teardown)],
    )
  tree_result(config, #(
    add_collected(
      Collected(results_rev: [], teardown_failures_rev: teardown_failures_rev),
      collected,
    ),
    completed,
    setup_processes_after,
  ))
}

/// Each test of a suite whose setup failed is `SetupFailed` with
/// `failure`. The teardown does not run.
fn suite_setup_failed(
  config: RunTreeConfig(context),
  setup_processes: SetupProcesses(context),
  failure: AssertionFailure,
) -> RunTreeParallelWithReporterResult {
  let results_rev =
    fail_group_nodes(config.groups, [], [tree_node(config)], [failure], [])
  tree_result(config, #(
    Collected(results_rev: results_rev, teardown_failures_rev: []),
    emit_test_finished_progress_results(
      progress_output(config.progress_reporter, config.write),
      config.completed,
      config.total,
      list.reverse(results_rev),
    ),
    setup_processes,
  ))
}

/// The process of the setup of a suite stopped before the setup
/// returned. No test runs, the run report gets a `SetupStopped` with each
/// test in `not_run`, and the teardown does not run: there is no value
/// to give it.
fn suite_setup_stopped(
  config: RunTreeConfig(context),
  setup_processes: SetupProcesses(context),
  scope: List(String),
  reason: String,
) -> RunTreeParallelWithReporterResult {
  let stop =
    Stop(setup: SuiteSetupHook, scope: scope, reason: reason, not_run: [])
  let results_rev =
    fail_group_nodes(
      config.groups,
      [],
      [tree_node(config)],
      [not_run_failure(stop)],
      [],
    )
  let results = list.reverse(results_rev)
  tree_result(config, #(
    Collected(results_rev: results_rev, teardown_failures_rev: [
      types.SetupStopped(
        setup: SuiteSetupHook,
        groups: scope,
        reason: reason,
        not_run: full_names(results),
      ),
    ]),
    emit_test_finished_progress_results(
      progress_output(config.progress_reporter, config.write),
      config.completed,
      config.total,
      results,
    ),
    setup_processes,
  ))
}

// =============================================================================
// Execution (sequential groups, one process per test)
// =============================================================================

fn execute_node(
  executor_input: ExecuteNodeConfig(context),
) -> #(Collected, Int, SetupProcesses(context)) {
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
    setup_processes: setup_processes,
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
      case
        run_before_all_chain(
          config,
          group_scope,
          None,
          context,
          hooks.before_all,
        )
      {
        BeforeAllFailed(
          setup_process: setup_process,
          context: ctx2,
          failure: failure,
        ) -> {
          // If before_all fails, do not execute any tests in this scope.
          // Instead, mark all tests under this group as SetupFailed and skip
          // their bodies.
          let group_results_rev =
            fail_tests_due_to_before_all(
              group_scope,
              combined_tags,
              tests,
              groups,
              [failure],
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
              before_all_scope(group_scope),
              alive_setup_process(group_scope, setup_process),
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
            setup_processes,
          )
        }

        BeforeAllRan(setup_process: setup_process, context: ctx2) -> {
          let combined_before_each =
            list.append(inherited_before_each, hooks.before_each)
          let combined_after_each =
            list.append(hooks.after_each, inherited_after_each)

          let scope_setup_processes =
            SetupProcesses(
              ..setup_processes,
              groups: list.append(
                setup_processes.groups,
                option.values([setup_process]),
              ),
            )
          let #(
            group_outcomes_rev,
            completed_after_tests,
            setup_processes_after_tests,
          ) =
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
              scope_setup_processes,
            )

          let #(
            after_groups,
            completed_after_groups,
            setup_processes_after_groups,
          ) =
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
              setup_processes_after_tests,
            )

          let #(outer_setup_processes, own_setup_process) =
            list.split(
              setup_processes_after_groups.groups,
              list.length(setup_processes.groups),
            )
          let teardown_failures_rev =
            finish_group_scope(
              config,
              before_all_scope(group_scope),
              list.first(own_setup_process) |> option.from_result,
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
            SetupProcesses(
              ..setup_processes_after_groups,
              groups: outer_setup_processes,
            ),
          )
        }
      }
    }

    _ -> #(base_collected, completed, setup_processes)
  }
}

/// The scope setup process of a group whose `before_all` hooks gave `setup_process`.
fn alive_setup_process(
  scope: List(String),
  setup_process: Option(GroupSetupProcess(context)),
) -> Option(ScopeSetupProcess(context)) {
  case setup_process {
    Some(setup_process) ->
      Some(SetupProcessAlive(
        scope: scope,
        setup_process: setup_process,
        setup: BeforeAllHook,
      ))
    None -> None
  }
}

/// Look again at each setup process that was alive. The check takes the down
/// message of a stopped setup process, so its reason is kept in `SetupProcessGone` and
/// `SetupStopped`.
fn refresh_setup_processes(
  setup_processes: SetupProcesses(context),
) -> SetupProcesses(context) {
  SetupProcesses(
    outer: list.map(setup_processes.outer, refresh_outer_setup),
    groups: list.map(setup_processes.groups, refresh_setup_process),
  )
}

fn refresh_outer_setup(scope: OuterSetup) -> OuterSetup {
  case scope {
    SetupRunning(setup: setup, groups: names, check_setup_process: check) ->
      checked_outer_setup(scope, setup, names, check())
    SetupStopped(..) -> scope
  }
}

fn checked_outer_setup(
  scope: OuterSetup,
  setup: SetupHook,
  names: List(String),
  checked: Result(Nil, String),
) -> OuterSetup {
  case checked {
    Ok(Nil) -> scope
    Error(reason) ->
      SetupStopped(setup: setup, groups: names, reason: reason, not_run: [])
  }
}

fn refresh_setup_process(
  setup_process: ScopeSetupProcess(context),
) -> ScopeSetupProcess(context) {
  case setup_process {
    SetupProcessAlive(scope: scope, setup_process: alive, setup: setup) ->
      checked_setup_process(
        scope,
        alive,
        setup,
        sandbox.check_setup_process(alive),
      )
    SetupProcessGone(..) -> setup_process
  }
}

fn checked_setup_process(
  scope: List(String),
  setup_process: GroupSetupProcess(context),
  setup: SetupHook,
  checked: Result(GroupSetupProcess(context), String),
) -> ScopeSetupProcess(context) {
  case checked {
    Ok(_alive) ->
      SetupProcessAlive(
        scope: scope,
        setup_process: setup_process,
        setup: setup,
      )
    Error(reason) ->
      SetupProcessGone(scope: scope, reason: reason, not_run: [], setup: setup)
  }
}

/// A setup whose process stopped, as the tests that it skips see it.
type Stop {
  Stop(
    setup: SetupHook,
    scope: List(String),
    reason: String,
    not_run: List(List(String)),
  )
}

/// The outermost setup whose process stopped: the failure of each test
/// that does not run because of it, and where it is in the setup processes, so
/// `record_not_run` can record those tests in it. The outer setups are
/// outside the group scopes.
type StoppedSetup(context) {
  StoppedSetup(
    failure: AssertionFailure,
    setup_processes: SetupProcesses(context),
    place: StopPlace(context),
  )
}

/// Where a stopped setup is: in the outer setups or in the group scopes.
type StopPlace(context) {
  OuterStopPlace(found: Found(OuterSetup, Stop))
  GroupStopPlace(found: Found(ScopeSetupProcess(context), Stop))
}

/// An item of a list and the items around it: the items before it, newest
/// first, and the items after it.
type Found(item, value) {
  Found(before_rev: List(item), value: value, after: List(item))
}

fn stopped_setup(
  setup_processes: SetupProcesses(context),
) -> Option(StoppedSetup(context)) {
  case
    find_first(setup_processes.outer, outer_stop, []),
    find_first(setup_processes.groups, group_stop, [])
  {
    Ok(found), _ ->
      Some(StoppedSetup(
        failure: not_run_failure(found.value),
        setup_processes: setup_processes,
        place: OuterStopPlace(found),
      ))
    Error(Nil), Ok(found) ->
      Some(StoppedSetup(
        failure: not_run_failure(found.value),
        setup_processes: setup_processes,
        place: GroupStopPlace(found),
      ))
    Error(Nil), Error(Nil) -> None
  }
}

/// The setup processes with `names` added to the tests that the stopped setup did
/// not run.
fn record_not_run(
  stopped: StoppedSetup(context),
  names: List(List(String)),
) -> SetupProcesses(context) {
  case stopped.place {
    OuterStopPlace(found: found) ->
      SetupProcesses(
        ..stopped.setup_processes,
        outer: rebuild(
          found,
          SetupStopped(
            setup: found.value.setup,
            groups: found.value.scope,
            reason: found.value.reason,
            not_run: list.append(found.value.not_run, names),
          ),
        ),
      )
    GroupStopPlace(found: found) ->
      SetupProcesses(
        ..stopped.setup_processes,
        groups: rebuild(
          found,
          SetupProcessGone(
            scope: found.value.scope,
            reason: found.value.reason,
            not_run: list.append(found.value.not_run, names),
            setup: found.value.setup,
          ),
        ),
      )
  }
}

/// The first item of `items` that `pick` gives `Ok` for.
fn find_first(
  items: List(item),
  pick: fn(item) -> Result(value, Nil),
  before_rev: List(item),
) -> Result(Found(item, value), Nil) {
  case items {
    [] -> Error(Nil)
    [item, ..rest] -> found_or_next(pick(item), item, rest, pick, before_rev)
  }
}

fn found_or_next(
  picked: Result(value, Nil),
  item: item,
  rest: List(item),
  pick: fn(item) -> Result(value, Nil),
  before_rev: List(item),
) -> Result(Found(item, value), Nil) {
  case picked {
    Ok(value) -> Ok(Found(before_rev: before_rev, value: value, after: rest))
    Error(Nil) -> find_first(rest, pick, [item, ..before_rev])
  }
}

/// The list of `found` with `replacement` in place of the item found.
fn rebuild(found: Found(item, value), replacement: item) -> List(item) {
  list.append(list.reverse(found.before_rev), [replacement, ..found.after])
}

fn outer_stop(setup: OuterSetup) -> Result(Stop, Nil) {
  case setup {
    SetupStopped(setup: setup, groups: scope, reason: reason, not_run: not_run) ->
      Ok(Stop(setup: setup, scope: scope, reason: reason, not_run: not_run))
    SetupRunning(..) -> Error(Nil)
  }
}

fn group_stop(setup_process: ScopeSetupProcess(context)) -> Result(Stop, Nil) {
  case setup_process {
    SetupProcessGone(
      scope: scope,
      reason: reason,
      not_run: not_run,
      setup: setup,
    ) -> Ok(Stop(setup: setup, scope: scope, reason: reason, not_run: not_run))
    SetupProcessAlive(..) -> Error(Nil)
  }
}

/// The failure of a test that was not run because `stop` stopped:
/// `not run: the setup from <setup hook> in "<groups>" stopped (<reason>)`,
/// without `in "<groups>"` for the whole run, or
/// `not run: the suite setup of "<suite>" stopped (<reason>)` for the
/// setup of a suite. The operator is the name of the setup hook.
fn not_run_failure(stop: Stop) -> AssertionFailure {
  AssertionFailure(
    operator: types.setup_hook_name(stop.setup),
    message: "not run: "
      <> stopped_setup_text(stop)
      <> " ("
      <> stop.reason
      <> ")",
    payload: None,
  )
}

/// `the suite setup of "<suite>" stopped` for the setup of a suite, and
/// `the setup from <setup hook> in "<groups>" stopped` for a hook.
fn stopped_setup_text(stop: Stop) -> String {
  case stop.setup {
    SuiteSetupHook ->
      "the suite setup of \"" <> string.join(stop.scope, " > ") <> "\" stopped"
    BeforeAllHook | BeforeEachSuiteHook | BeforeAllSuitesHook ->
      "the setup from "
      <> types.setup_hook_name(stop.setup)
      <> quoted_scope(stop.scope)
      <> " stopped"
  }
}

/// ` in "<groups>"` for a scope, with its names joined by ` > `, or `""`
/// for the whole run.
fn quoted_scope(scope: List(String)) -> String {
  case scope {
    [] -> ""
    _ -> " in \"" <> string.join(scope, " > ") <> "\""
  }
}

/// The full name of each result, in order.
fn full_names(results: List(TestResult)) -> List(List(String)) {
  list.map(results, result_full_name)
}

fn result_full_name(result: TestResult) -> List(String) {
  types.full_name(result.groups, result.name)
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

/// The results and teardown failures of test outcomes that are newest
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
// The setup process of a group
// =============================================================================

/// Run a group hook in the setup process of the group. A teardown hook
/// gives back the context that it got, so both kinds of hook have one
/// result type.
fn run_group_hook(call: GroupHookCall(context)) -> Result(context, String) {
  case call {
    StartCall(setup: setup) -> setup()
    SetupCall(hook: hook, context: context) -> types.call(hook, context)
    TeardownCall(hook: hook, context: context) ->
      types.call(hook, context)
      |> result.replace(context)
  }
}

/// The result of the `before_all` hooks of a group, by cause.
type BeforeAllResult(context) {
  /// Every hook returned `Ok`, or the setup process exited. `setup_process` is
  /// `SetupProcessGone` when the setup process exited: the setup stopped, so the tests
  /// of the group are not run, and its `after_all` hooks run in a new
  /// setup process. `setup_process` is `None` when the group has no `before_all` hook.
  BeforeAllRan(
    setup_process: Option(ScopeSetupProcess(context)),
    context: context,
  )
  /// A hook returned `Error`, crashed inside the hook call, or timed out.
  /// `setup_process` is the setup process when it is still alive.
  BeforeAllFailed(
    setup_process: Option(GroupSetupProcess(context)),
    context: context,
    failure: AssertionFailure,
  )
}

/// Run the `before_all` hooks of a group in the setup process of the
/// group, and stop at the first failure or when the setup process exits. The first
/// hook starts the setup process. Each hook gets the default timeout.
///
/// A hook that returns `Error`, crashes or times out is a failure of the
/// hook. A setup process that exits, while a hook runs or between two
/// hooks, stops the setup. The context is the context after the last
/// hook that returned.
fn run_before_all_chain(
  config: ParallelConfig,
  scope: List(String),
  setup_process: Option(GroupSetupProcess(context)),
  context: context,
  hooks: List(Callback(context, Result(context, String))),
) -> BeforeAllResult(context) {
  case hooks {
    [] ->
      BeforeAllRan(
        setup_process: alive_setup_process(scope, setup_process),
        context: context,
      )
    [hook, ..rest] ->
      before_all_result(
        config,
        scope,
        context,
        rest,
        sandbox.run_in_setup_process(
          setup_process,
          config.default_timeout_ms,
          run_group_hook,
          SetupCall(hook: hook, context: context),
        ),
      )
  }
}

fn before_all_result(
  config: ParallelConfig,
  scope: List(String),
  context: context,
  rest: List(Callback(context, Result(context, String))),
  setup_process_result: SetupProcessResult(
    GroupHookCall(context),
    Result(context, String),
  ),
) -> BeforeAllResult(context) {
  case setup_process_result {
    SetupProcessReturned(setup_process: setup_process, value: Ok(next)) ->
      run_before_all_chain(config, scope, Some(setup_process), next, rest)
    SetupProcessReturned(setup_process: setup_process, value: Error(message)) ->
      BeforeAllFailed(
        setup_process: Some(setup_process),
        context: context,
        failure: hook_failure("before_all", message),
      )
    SetupProcessCaught(setup_process: setup_process, reason: reason) ->
      BeforeAllFailed(
        setup_process: Some(setup_process),
        context: context,
        failure: hook_failure("before_all", hook_crash_message(scope, reason)),
      )
    SetupProcessTimedOut ->
      BeforeAllFailed(
        setup_process: None,
        context: context,
        failure: hook_failure("before_all", hook_timeout_message(scope)),
      )
    SetupProcessExited(reason: reason) | SetupProcessLost(reason: reason) ->
      BeforeAllRan(
        setup_process: Some(SetupProcessGone(
          scope: scope,
          reason: reason,
          not_run: [],
          setup: BeforeAllHook,
        )),
        context: context,
      )
  }
}

/// End the scope of a group: report a setup process that stopped while the tests
/// ran, run every `after_all` hook (in the setup process while it is alive, else
/// in a new setup process), then stop the setup process. Gives the teardown failures
/// newest first.
fn finish_group_scope(
  config: ParallelConfig,
  scope: GroupScope,
  setup_process: Option(ScopeSetupProcess(context)),
  context: context,
  hooks: List(Callback(context, Result(Nil, String))),
) -> List(TeardownFailure) {
  case setup_process, hooks {
    None, _ -> run_after_all_hooks(config, scope, None, context, hooks, [])
    Some(SetupProcessGone(reason: reason, not_run: not_run, ..)), _ ->
      run_after_all_hooks(config, scope, None, context, hooks, [
        group_setup_stopped(scope, reason, not_run),
      ])
    Some(SetupProcessAlive(setup_process: alive, ..)), [] ->
      stop_checked_setup_process(scope, sandbox.check_setup_process(alive))
    Some(SetupProcessAlive(setup_process: alive, ..)), _ ->
      run_after_all_hooks(config, scope, Some(alive), context, hooks, [])
  }
}

/// A group scope at its end: its names and the names of its hooks.
type GroupScope {
  GroupScope(groups: List(String), hooks: ScopeHooks)
}

/// The scope of a group with `before_all` and `after_all` hooks.
fn before_all_scope(groups: List(String)) -> GroupScope {
  GroupScope(groups: groups, hooks: scope_hooks(BeforeAllHook))
}

/// Run the `after_all` hooks, then stop the last setup process.
fn run_after_all_hooks(
  config: ParallelConfig,
  scope: GroupScope,
  setup_process: Option(GroupSetupProcess(context)),
  context: context,
  hooks: List(Callback(context, Result(Nil, String))),
  failures_rev: List(TeardownFailure),
) -> List(TeardownFailure) {
  let #(last_setup_process, next_failures_rev) =
    run_after_all_chain(
      config,
      scope,
      setup_process,
      context,
      hooks,
      failures_rev,
    )
  let _stopped = option.map(last_setup_process, sandbox.stop_setup_process)
  next_failures_rev
}

/// Stop the setup process of a scope with no `after_all` hook, or report that it
/// stopped already.
fn stop_checked_setup_process(
  scope: GroupScope,
  checked: Result(GroupSetupProcess(context), String),
) -> List(TeardownFailure) {
  case checked {
    Ok(setup_process) -> {
      sandbox.stop_setup_process(setup_process)
      []
    }
    Error(reason) -> [group_setup_stopped(scope, reason, [])]
  }
}

fn group_setup_stopped(
  scope: GroupScope,
  reason: String,
  not_run: List(List(String)),
) -> TeardownFailure {
  types.SetupStopped(
    setup: scope.hooks.setup,
    groups: scope.groups,
    reason: reason,
    not_run: not_run,
  )
}

/// Run every `after_all` hook of a group, also after one fails, and give
/// the failures newest first, in front of `failures_rev`. Each hook gets
/// the default timeout. After a timeout or an exit of the setup process, the next
/// hook runs in a new setup process.
fn run_after_all_chain(
  config: ParallelConfig,
  scope: GroupScope,
  setup_process: Option(GroupSetupProcess(context)),
  context: context,
  hooks: List(Callback(context, Result(Nil, String))),
  failures_rev: List(TeardownFailure),
) -> #(Option(GroupSetupProcess(context)), List(TeardownFailure)) {
  case hooks {
    [] -> #(setup_process, failures_rev)
    [hook, ..rest] ->
      after_all_result(
        AfterAllStep(
          config: config,
          scope: scope,
          context: context,
          hook: hook,
          rest: rest,
        ),
        sandbox.run_in_setup_process(
          setup_process,
          config.default_timeout_ms,
          run_group_hook,
          TeardownCall(hook: hook, context: context),
        ),
        failures_rev,
      )
  }
}

/// One `after_all` hook of a group and the hooks after it.
type AfterAllStep(context) {
  AfterAllStep(
    config: ParallelConfig,
    scope: GroupScope,
    context: context,
    hook: Callback(context, Result(Nil, String)),
    rest: List(Callback(context, Result(Nil, String))),
  )
}

/// Record the result of an `after_all` hook and run the hooks after it.
/// A setup process that stopped before the hook started means that the setup
/// stopped: the hook runs again in a new setup process, so it never stays not run.
fn after_all_result(
  step: AfterAllStep(context),
  setup_process_result: SetupProcessResult(
    GroupHookCall(context),
    Result(context, String),
  ),
  failures_rev: List(TeardownFailure),
) -> #(Option(GroupSetupProcess(context)), List(TeardownFailure)) {
  let AfterAllStep(
    config: config,
    scope: scope,
    context: context,
    hook: hook,
    rest: rest,
  ) = step
  case setup_process_result {
    SetupProcessReturned(setup_process: setup_process, value: Ok(_context)) ->
      run_after_all_chain(
        config,
        scope,
        Some(setup_process),
        context,
        rest,
        failures_rev,
      )
    SetupProcessReturned(setup_process: setup_process, value: Error(message)) ->
      run_after_all_chain(
        config,
        scope,
        Some(setup_process),
        context,
        rest,
        add_teardown_failure(scope, message, failures_rev),
      )
    SetupProcessCaught(setup_process: setup_process, reason: reason) ->
      run_after_all_chain(
        config,
        scope,
        Some(setup_process),
        context,
        rest,
        add_teardown_failure(
          scope,
          scope_crash_message(scope.hooks.teardown_text, scope.groups, reason),
          failures_rev,
        ),
      )
    SetupProcessTimedOut ->
      run_after_all_chain(
        config,
        scope,
        None,
        context,
        rest,
        add_teardown_failure(
          scope,
          scope_timeout_message(scope.hooks.teardown_text, scope.groups),
          failures_rev,
        ),
      )
    SetupProcessExited(reason: reason) ->
      run_after_all_chain(
        config,
        scope,
        None,
        context,
        rest,
        add_teardown_failure(
          scope,
          scope_crash_message(scope.hooks.teardown_text, scope.groups, reason),
          failures_rev,
        ),
      )
    SetupProcessLost(reason: reason) ->
      run_after_all_chain(config, scope, None, context, [hook, ..rest], [
        group_setup_stopped(scope, reason, []),
        ..failures_rev
      ])
  }
}

/// Put a failure of the teardown of a group scope in front of
/// `failures_rev`.
fn add_teardown_failure(
  scope: GroupScope,
  message: String,
  failures_rev: List(TeardownFailure),
) -> List(TeardownFailure) {
  [
    TeardownFailure(
      hook: scope.hooks.teardown,
      groups: scope.groups,
      message: message,
    ),
    ..failures_rev
  ]
}

fn run_child_groups_sequentially(
  config: ParallelConfig,
  scope: List(String),
  inherited_tags: List(String),
  context: context,
  runner_before_each_test: List(fn(TestInfo) -> Result(Nil, String)),
  runner_after_each_test: List(fn(TestInfo) -> Result(Nil, String)),
  before_each_hooks: List(Callback(context, Result(context, String))),
  after_each_hooks: List(Callback(context, Result(Nil, String))),
  groups: List(Node(context)),
  progress_output: Option(ProgressOutput),
  total: Int,
  completed: Int,
  collected: Collected,
  setup_processes: SetupProcesses(context),
) -> #(Collected, Int, SetupProcesses(context)) {
  case groups {
    [] -> #(collected, completed, setup_processes)
    [group_node, ..rest] -> {
      let node_config =
        ExecuteNodeConfig(
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
          setup_processes: refresh_setup_processes(setup_processes),
        )
      let #(next_collected, next_completed, next_setup_processes) =
        execute_or_fail_group(node_config)
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
        next_setup_processes,
      )
    }
  }
}

/// Run a child group while the process of each setup around it is alive.
/// After one stopped, the group does not start: no hook of it runs, each
/// of its tests is `SetupFailed`, and the outermost stopped setup records
/// them as not run.
fn execute_or_fail_group(
  node_config: ExecuteNodeConfig(context),
) -> #(Collected, Int, SetupProcesses(context)) {
  case stopped_setup(node_config.setup_processes) {
    None -> execute_node(node_config)
    Some(stopped) ->
      fail_after_stop(
        node_config.scope,
        node_config.inherited_tags,
        node_config.node,
        stopped,
        node_config.progress_output,
        node_config.completed,
        node_config.total,
        node_config.collected,
      )
  }
}

/// Each test of `node` is `SetupFailed` because the setup `stopped`
/// stopped, and that setup records them as not run. No hook of `node`
/// runs.
fn fail_after_stop(
  scope: List(String),
  inherited_tags: List(String),
  node: Node(context),
  stopped: StoppedSetup(context),
  progress_output: Option(ProgressOutput),
  completed: Int,
  total: Int,
  collected: Collected,
) -> #(Collected, Int, SetupProcesses(context)) {
  let results_rev =
    fail_group_nodes(scope, inherited_tags, [node], [stopped.failure], [])
  let results = list.reverse(results_rev)
  #(
    add_collected(
      Collected(results_rev: results_rev, teardown_failures_rev: []),
      collected,
    ),
    emit_test_finished_progress_results(
      progress_output,
      completed,
      total,
      results,
    ),
    record_not_run(stopped, full_names(results)),
  )
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
  setup_processes: SetupProcesses(context),
) -> #(List(TestOutcome), Int, SetupProcesses(context)) {
  run_loop(
    group,
    LoopState(
      pending: index_tests(tests, 0, []),
      running: [],
      pending_emit: [],
      emitted_rev: [],
      next_emit_index: 0,
      completed: completed,
      setup_processes: setup_processes,
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
) -> #(List(TestOutcome), Int, SetupProcesses(context)) {
  let started =
    emit_ready(start_tests_up_to_limit(group, state, timing.now_ms()))
  case started.running {
    [] -> #(started.emitted_rev, started.completed, started.setup_processes)
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
    [next, ..rest], True ->
      start_or_fail_next(
        group,
        LoopState(
          ..state,
          setup_processes: refresh_setup_processes(state.setup_processes),
        ),
        next,
        rest,
        now,
      )
    _, _ -> state
  }
}

/// Start the next test while the setup process of each scope is alive. After an
/// setup process stopped, no test that waits starts: each one is `SetupFailed`,
/// and the outermost stopped setup records it as not run.
fn start_or_fail_next(
  group: GroupRun(context),
  state: LoopState(context),
  next: #(Int, TestCase(context)),
  rest: List(#(Int, TestCase(context))),
  now: Int,
) -> LoopState(context) {
  let #(index, test_case) = next
  case stopped_setup(state.setup_processes) {
    Some(stopped) -> {
      let results = not_run_results(group, stopped.failure, [next, ..rest], [])
      add_results(
        group,
        LoopState(
          ..state,
          pending: [],
          setup_processes: record_not_run(
            stopped,
            full_names(list.map(results, indexed_result_value)),
          ),
        ),
        results,
      )
    }
    None ->
      start_tests_up_to_limit(
        group,
        LoopState(..state, pending: rest, running: [
          spawn_test_process(new_test_job(group, index, test_case, now), now),
          ..state.running
        ]),
        now,
      )
  }
}

/// A `SetupFailed` result with `failure` for each test that waits.
fn not_run_results(
  group: GroupRun(context),
  failure: AssertionFailure,
  pending: List(#(Int, TestCase(context))),
  results_rev: List(IndexedResult),
) -> List(IndexedResult) {
  case pending {
    [] -> list.reverse(results_rev)
    [#(index, test_case), ..rest] ->
      not_run_results(group, failure, rest, [
        IndexedResult(
          index: index,
          outcome: TestOutcome(
            result: TestResult(
              name: test_case.name,
              groups: group.scope,
              status: SetupFailed,
              duration_ms: 0,
              tags: list.append(group.inherited_tags, test_case.tags),
              failures: [failure],
              kind: test_case.kind,
            ),
            teardown_failures: [],
          ),
        ),
        ..results_rev
      ])
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
  let setup_steps =
    list.append(
      list.map(group.runner_before_each_test, RunnerBeforeEachStep),
      list.map(group.before_each_hooks, BeforeEachStep),
    )
  let teardown_steps =
    list.append(
      list.map(group.after_each_hooks, AfterEachStep),
      list.map(group.runner_after_each_test, RunnerAfterEachStep),
    )
  let #(first_step, later_steps) = case setup_steps {
    [] -> #(BodyStep, teardown_steps)
    [first, ..rest] -> #(
      first,
      list.flatten([rest, [BodyStep], teardown_steps]),
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
    killed: None,
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
    Error(Nil) ->
      LoopState(
        ..state,
        running: expire_workers(state.running, timing.now_ms(), []),
      )
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
        after_step_end(worker.job, ended_step(worker, down), kept_rev, results)
      remove_down_worker(rest, down, next_kept_rev, next_results)
    }
    [worker, ..rest] ->
      remove_down_worker(rest, down, [worker, ..kept_rev], results)
  }
}

/// The step in which a process stopped. After a kill at a deadline, it is
/// the step that ran at the kill, and it timed out. Else it is the current
/// step, and the exit reason says why it stopped.
///
/// After a kill, the state is the newest state that the process sent. When
/// no step started after the kill, it is the state when the killed step
/// started. When the killed step finished and a later step started before
/// the kill reached the process, it holds the context and the teardown
/// failures of the steps that finished, so the teardown steps that run
/// again get that context.
fn ended_step(
  worker: RunningWorker(context),
  down: Down,
) -> EndedStep(context) {
  case worker.killed {
    Some(killed) ->
      EndedStep(
        step: killed.step,
        state: worker.state,
        later_steps: steps_after_kill(killed, worker),
        end: StepTimedOut,
      )
    None ->
      EndedStep(
        step: worker.step,
        state: worker.state,
        later_steps: worker.later_steps,
        end: StepExited(sandbox.format_exit_reason(down.reason)),
      )
  }
}

/// The steps that did not finish after a kill: the steps after the killed
/// step, without those that finished.
///
/// The killed step timed out, so it is never in the list. Each step that
/// the process started after the kill means that the step before it
/// finished. Thus, when no step or one step started after the kill, no
/// step after the killed step finished, and all of them remain. When the
/// process started a later step before the kill reached it, that step did
/// not finish, so it is the first of the steps: a teardown step that the
/// killed process started runs again in a new process.
///
/// This uses counts and not a `case` on "did a step start after the kill",
/// because no test can put a message between the deadline and the kill.
/// A `case` arm for that race would be a line that no test runs.
fn steps_after_kill(
  killed: KilledStep(context),
  worker: RunningWorker(context),
) -> List(TestStep(context)) {
  let steps_started_after_kill =
    list.length(killed.later_steps) - list.length(worker.later_steps)
  let later_steps_finished = int.max(steps_started_after_kill - 1, 0)
  list.drop(killed.later_steps, later_steps_finished)
}

/// Kill each process whose step is past its deadline, and keep the step
/// that ran at the kill as the step that timed out. The process stays in
/// the list until the loop reads its down message. The messages that it
/// sent before the kill come before that down message, so the loop reads
/// each of them first: a process that sent its outcome just before the
/// kill keeps that outcome. Its teardown steps start after the down
/// message, when what it held is free. A process that does not stop by
/// its new deadline is killed again, and the first kill stays.
fn expire_workers(
  running: List(RunningWorker(context)),
  now: Int,
  kept_rev: List(RunningWorker(context)),
) -> List(RunningWorker(context)) {
  case running {
    [] -> list.reverse(kept_rev)
    [worker, ..rest] if worker.deadline_ms <= now -> {
      process.kill(worker.pid)
      expire_workers(rest, now, [
        RunningWorker(
          ..worker,
          killed: option.or(
            worker.killed,
            Some(KilledStep(step: worker.step, later_steps: worker.later_steps)),
          ),
          deadline_ms: now + worker.job.default_timeout_ms,
        ),
        ..kept_rev
      ])
    }
    [worker, ..rest] -> expire_workers(rest, now, [worker, ..kept_rev])
  }
}

/// After a step did not finish: record the failure of the step, then run
/// the teardown steps that did not finish yet in a new process, with the
/// context that they would get after the body. With no such step, the
/// test has its outcome.
fn after_step_end(
  job: TestJob(context),
  ended: EndedStep(context),
  kept_rev: List(RunningWorker(context)),
  results: List(IndexedResult),
) -> #(List(RunningWorker(context)), List(IndexedResult)) {
  let state = fail_step(job, ended.step, ended.state, ended.end)
  case list.filter(ended.later_steps, is_teardown_step) {
    [] -> #(kept_rev, [
      IndexedResult(index: job.index, outcome: test_outcome(job, state)),
      ..results
    ])
    [first, ..rest] -> {
      let next_job =
        TestJob(..job, first_step: first, later_steps: rest, state: state)
      #([spawn_test_process(next_job, timing.now_ms()), ..kept_rev], results)
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
/// The body of a test process: run the steps, send the outcome, then exit
/// with reason `shutdown`. A process that links to the test process and
/// does not trap exits, such as an actor that the test started, stops with
/// it, whether the test passed, failed or crashed. A normal exit would not
/// stop it.
fn run_test_process(job: TestJob(context)) -> Nil {
  let state = run_steps(job, [job.first_step, ..job.later_steps], job.state)
  send(
    job.subject,
    WorkerFinished(worker: process.self(), outcome: test_outcome(job, state)),
  )
  exit(atom.create("shutdown"))
}

/// Exit the calling process with `reason`.
@external(erlang, "erlang", "exit")
fn exit(reason: Atom) -> Nil

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

/// Run a step when it is due: a teardown step always, a setup step and
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
      runner_setup_step_result(
        job,
        state,
        sandbox.run_catching(
          call_runner_hook,
          RunnerHookCall(hook: hook, info: job.info),
        ),
      )
    BeforeEachStep(hook: hook) ->
      setup_step_result(
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
      teardown_step_result(
        job,
        state,
        AfterEachHook,
        sandbox.run_catching(
          call_hook,
          HookCall(hook: hook, input: state.context),
        ),
      )
    RunnerAfterEachStep(hook: hook) ->
      teardown_step_result(
        job,
        state,
        AfterEachTestHook,
        sandbox.run_catching(
          call_runner_hook,
          RunnerHookCall(hook: hook, info: job.info),
        ),
      )
  }
}

fn setup_step_result(
  job: TestJob(context),
  state: TestState(context),
  operator: String,
  caught: Result(Result(context, String), String),
) -> TestState(context) {
  case caught {
    Ok(Ok(next)) -> TestState(..state, context: next)
    Ok(Error(message)) -> setup_failed(state, operator, message)
    Error(reason) ->
      setup_failed(state, operator, hook_crash_message(job.scope, reason))
  }
}

/// The result of a runner `before_each_test` hook. It gets only the
/// `TestInfo`, so the context stays as it is.
fn runner_setup_step_result(
  job: TestJob(context),
  state: TestState(context),
  caught: Result(Result(Nil, String), String),
) -> TestState(context) {
  case caught {
    Ok(Ok(Nil)) -> state
    Ok(Error(message)) -> setup_failed(state, "before_each_test", message)
    Error(reason) ->
      setup_failed(
        state,
        "before_each_test",
        hook_crash_message(job.scope, reason),
      )
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
    Ok(AssertionPending) -> TestState(..state, status: Pending)
    Error(reason) -> body_ended(state, Failed, hook_failure("crash", reason))
  }
}

fn teardown_step_result(
  job: TestJob(context),
  state: TestState(context),
  hook: TeardownHook,
  caught: Result(Result(Nil, String), String),
) -> TestState(context) {
  case caught {
    Ok(Ok(Nil)) -> state
    Ok(Error(message)) -> teardown_failed(job, state, hook, message)
    Error(reason) ->
      teardown_failed(job, state, hook, hook_crash_message(job.scope, reason))
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
      setup_failed(state, "before_each_test", step_end_message(job, end))
    BeforeEachStep(_), _ ->
      setup_failed(state, "before_each", step_end_message(job, end))
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
      teardown_failed(job, state, AfterEachHook, step_end_message(job, end))
    RunnerAfterEachStep(_), _ ->
      teardown_failed(job, state, AfterEachTestHook, step_end_message(job, end))
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

fn setup_failed(
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

fn teardown_failed(
  job: TestJob(context),
  state: TestState(context),
  hook: TeardownHook,
  message: String,
) -> TestState(context) {
  TestState(..state, teardown_failures_rev: [
    TeardownFailure(
      hook: hook,
      groups: types.full_name(job.scope, job.test_case.name),
      message: message,
    ),
    ..state.teardown_failures_rev
  ])
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
type RunnerHookCall {
  RunnerHookCall(hook: fn(TestInfo) -> Result(Nil, String), info: TestInfo)
}

fn call_runner_hook(call: RunnerHookCall) -> Result(Nil, String) {
  call.hook(call.info)
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
  scope_crash_message("hook", scope, reason)
}

fn hook_timeout_message(scope: List(String)) -> String {
  scope_timeout_message("hook", scope)
}

/// `<text> crashed in <groups>: <reason>`, for example
/// `the suite setup crashed in Server: error:boom`.
fn scope_crash_message(
  text: String,
  scope: List(String),
  reason: String,
) -> String {
  text <> " crashed in " <> string.join(scope, " > ") <> ": " <> reason
}

/// `<text> timed out in <groups>`.
fn scope_timeout_message(text: String, scope: List(String)) -> String {
  text <> " timed out in " <> string.join(scope, " > ")
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
