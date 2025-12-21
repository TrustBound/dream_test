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
//// ## Example (from snippets)
////
//// ```gleam
//// // examples/snippets/test/snippets/utils/parallel_direct.gleam
//// import dream_test/parallel
//// import dream_test/unit.{describe, it}
//// import dream_test/matchers.{have_length, or_fail_with, should, succeed}
////
//// let suite =
////   describe("Suite", [
////     it("a", fn() { Ok(succeed()) }),
////     it("b", fn() { Ok(succeed()) }),
////   ])
////
//// parallel.run_root_parallel(parallel.default_config(), suite)
//// |> should
//// |> have_length(2)
//// |> or_fail_with("expected two results")
//// ```

import dream_test/reporters.{type Reporter, handle_event}
import dream_test/reporters/types as reporter_types
import dream_test/sandbox
import dream_test/timing
import dream_test/types.{
  type AssertionFailure, type AssertionResult, type Node, type Status,
  type TestResult, type TestSuite, AfterAll, AfterEach, AssertionFailed,
  AssertionFailure, AssertionOk, AssertionSkipped, BeforeAll, BeforeEach, Failed,
  Group, Passed, Root, SetupFailed, Test, TestResult, TimedOut, Unit,
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
pub type ParallelConfig {
  ParallelConfig(max_concurrency: Int, default_timeout_ms: Int)
}

type IndexedResult {
  IndexedResult(index: Int, result: TestResult)
}

type RunningTest {
  RunningTest(index: Int, pid: Pid, deadline_ms: Int)
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
pub fn default_config() -> ParallelConfig {
  ParallelConfig(max_concurrency: 4, default_timeout_ms: 5000)
}

/// Run a single suite and return results.
///
/// This does **not** drive a reporter.
pub fn run_root_parallel(
  config: ParallelConfig,
  suite: TestSuite(context),
) -> List(TestResult) {
  let Root(seed, tree) = suite
  execute_node(config, [], [], seed, [], [], tree, []) |> list.reverse
}

/// Run a single suite while driving a reporter.
///
/// This is used by `dream_test/runner` internally.
///
/// - `total` is the total number of tests across all suites in the run
/// - `completed` is how many tests have already completed before this suite
pub fn run_root_parallel_with_reporter(
  config: ParallelConfig,
  suite: TestSuite(context),
  reporter0: Reporter,
  total: Int,
  completed: Int,
) -> #(List(TestResult), Int, Reporter) {
  let Root(seed, tree) = suite
  let #(results_rev, reporter1, completed1) =
    execute_node_with_reporter(
      config,
      [],
      [],
      seed,
      [],
      [],
      tree,
      reporter0,
      total,
      completed,
      [],
    )
  #(list.reverse(results_rev), completed1, reporter1)
}

// =============================================================================
// Execution (sequential groups, tests executed with sandbox + timeout)
// =============================================================================

fn execute_node(
  config: ParallelConfig,
  scope: List(String),
  inherited_tags: List(String),
  context: context,
  inherited_before_each: List(fn(context) -> Result(context, String)),
  inherited_after_each: List(fn(context) -> Result(Nil, String)),
  node: Node(context),
  acc_rev: List(TestResult),
) -> List(TestResult) {
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
          let results_rev =
            fail_tests_due_to_before_all(
              group_scope,
              combined_tags,
              tests,
              groups,
              failures_rev,
              [],
            )

          let final_rev =
            run_after_all_chain(
              config,
              group_scope,
              ctx2,
              hooks.after_all,
              results_rev,
            )

          list.append(final_rev, acc_rev)
        }

        True -> {
          let combined_before_each =
            list.append(inherited_before_each, hooks.before_each)
          let combined_after_each =
            list.append(hooks.after_each, inherited_after_each)

          let results_rev =
            run_tests_in_group(
              config,
              group_scope,
              combined_tags,
              ctx2,
              combined_before_each,
              combined_after_each,
              tests,
              failures_rev,
            )

          let after_group_rev =
            run_child_groups_sequentially(
              config,
              group_scope,
              combined_tags,
              ctx2,
              combined_before_each,
              combined_after_each,
              groups,
              results_rev,
            )

          let final_rev =
            run_after_all_chain(
              config,
              group_scope,
              ctx2,
              hooks.after_all,
              after_group_rev,
            )

          list.append(final_rev, acc_rev)
        }
      }
    }

    _ -> acc_rev
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
    [Test(name, tags, kind, _run, _timeout_ms), ..rest] -> {
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
  before_each_hooks: List(fn(context) -> Result(context, String)),
  after_each_hooks: List(fn(context) -> Result(Nil, String)),
  tests: List(Node(context)),
  failures_rev: List(AssertionFailure),
) -> List(TestResult) {
  let ParallelConfig(max_concurrency: max_concurrency, default_timeout_ms: _) =
    config
  case max_concurrency <= 1 {
    True ->
      run_tests_sequentially(
        config,
        scope,
        inherited_tags,
        context,
        before_each_hooks,
        after_each_hooks,
        tests,
        failures_rev,
        [],
      )
    False ->
      run_tests_parallel(
        config,
        scope,
        inherited_tags,
        context,
        before_each_hooks,
        after_each_hooks,
        tests,
        failures_rev,
      )
  }
}

fn run_tests_parallel(
  config: ParallelConfig,
  scope: List(String),
  inherited_tags: List(String),
  context: context,
  before_each_hooks: List(fn(context) -> Result(context, String)),
  after_each_hooks: List(fn(context) -> Result(Nil, String)),
  tests: List(Node(context)),
  failures_rev: List(AssertionFailure),
) -> List(TestResult) {
  let subject = new_subject()
  let indexed = index_tests(tests, 0, [])
  let ParallelConfig(max_concurrency: max_concurrency, default_timeout_ms: _) =
    config

  run_parallel_loop(
    config,
    subject,
    scope,
    inherited_tags,
    context,
    before_each_hooks,
    after_each_hooks,
    failures_rev,
    indexed,
    [],
    [],
    [],
    0,
    max_concurrency,
  )
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
  config: ParallelConfig,
  subject: Subject(WorkerMessage),
  scope: List(String),
  inherited_tags: List(String),
  context: context,
  before_each_hooks: List(fn(context) -> Result(context, String)),
  after_each_hooks: List(fn(context) -> Result(Nil, String)),
  failures_rev: List(AssertionFailure),
  pending: List(#(Int, Node(context))),
  running: List(RunningTest),
  pending_emit: List(IndexedResult),
  emitted_rev: List(TestResult),
  next_emit_index: Int,
  max_concurrency: Int,
) -> List(TestResult) {
  let #(pending2, running2) =
    start_workers_up_to_limit(
      config,
      subject,
      scope,
      inherited_tags,
      context,
      before_each_hooks,
      after_each_hooks,
      failures_rev,
      pending,
      running,
      max_concurrency,
    )

  case list.is_empty(pending2) && list.is_empty(running2) {
    True ->
      list.append(
        list.reverse(emitted_rev),
        emit_all_results(pending_emit, next_emit_index, []),
      )
    False -> {
      let #(pending3, running3, pending_emit2) =
        wait_for_event_or_timeout(
          config,
          subject,
          scope,
          pending2,
          running2,
          pending_emit,
        )

      let #(maybe_ready, remaining_emit) =
        take_indexed_result(next_emit_index, pending_emit2, [])

      case maybe_ready {
        None ->
          run_parallel_loop(
            config,
            subject,
            scope,
            inherited_tags,
            context,
            before_each_hooks,
            after_each_hooks,
            failures_rev,
            pending3,
            running3,
            remaining_emit,
            emitted_rev,
            next_emit_index,
            max_concurrency,
          )
        Some(IndexedResult(_, result)) ->
          run_parallel_loop(
            config,
            subject,
            scope,
            inherited_tags,
            context,
            before_each_hooks,
            after_each_hooks,
            failures_rev,
            pending3,
            running3,
            remaining_emit,
            [result, ..emitted_rev],
            next_emit_index + 1,
            max_concurrency,
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
  config: ParallelConfig,
  subject: Subject(WorkerMessage),
  scope: List(String),
  inherited_tags: List(String),
  context: context,
  before_each_hooks: List(fn(context) -> Result(context, String)),
  after_each_hooks: List(fn(context) -> Result(Nil, String)),
  failures_rev: List(AssertionFailure),
  pending: List(#(Int, Node(context))),
  running: List(RunningTest),
  max_concurrency: Int,
) -> #(List(#(Int, Node(context))), List(RunningTest)) {
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
              before_each_hooks,
              after_each_hooks,
              failures_rev,
              index,
              test_node,
            )
          start_workers_up_to_limit(
            config,
            subject,
            scope,
            inherited_tags,
            context,
            before_each_hooks,
            after_each_hooks,
            failures_rev,
            rest,
            [
              RunningTest(index: index, pid: pid, deadline_ms: deadline_ms),
              ..running
            ],
            max_concurrency,
          )
        }
      }
  }
}

fn spawn_test_worker(
  config: ParallelConfig,
  subject: Subject(WorkerMessage),
  scope: List(String),
  inherited_tags: List(String),
  context: context,
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
    Test(_, _, _, _, Some(ms)) -> ms
    _ -> default_timeout_ms
  }
}

fn wait_for_event_or_timeout(
  config: ParallelConfig,
  subject: Subject(WorkerMessage),
  scope: List(String),
  pending: List(#(Int, Node(context))),
  running: List(RunningTest),
  pending_emit: List(IndexedResult),
) -> #(List(#(Int, Node(context))), List(RunningTest), List(IndexedResult)) {
  let selector = new_selector() |> select(subject)

  let now = timing.now_ms()
  let next_timeout = next_deadline_timeout(running, now, 1000)
  case selector_receive(selector, next_timeout) {
    Ok(message) ->
      handle_worker_message(scope, message, pending, running, pending_emit)
    Error(Nil) -> handle_timeouts(config, pending, running, pending_emit)
  }
}

fn handle_worker_message(
  scope: List(String),
  message: WorkerMessage,
  pending: List(#(Int, Node(context))),
  running: List(RunningTest),
  pending_emit: List(IndexedResult),
) -> #(List(#(Int, Node(context))), List(RunningTest), List(IndexedResult)) {
  case message {
    WorkerCompleted(index, result) -> #(
      pending,
      remove_running_by_index(running, index),
      [IndexedResult(index: index, result: result), ..pending_emit],
    )
    WorkerCrashed(index, reason) -> {
      let failure =
        hook_failure(
          "crash",
          "worker crashed in " <> string.join(scope, " > ") <> ": " <> reason,
        )
      let result =
        TestResult(
          name: "<crash>",
          full_name: list.append(scope, ["<crash>"]),
          status: Failed,
          duration_ms: 0,
          tags: [],
          failures: [failure],
          kind: Unit,
        )
      #(pending, remove_running_by_index(running, index), [
        IndexedResult(index: index, result: result),
        ..pending_emit
      ])
    }
  }
}

fn handle_timeouts(
  _config: ParallelConfig,
  pending: List(#(Int, Node(context))),
  running: List(RunningTest),
  pending_emit: List(IndexedResult),
) -> #(List(#(Int, Node(context))), List(RunningTest), List(IndexedResult)) {
  let now = timing.now_ms()
  let #(timed_out, still_running) = partition_timeouts(running, now, [], [])
  list.each(timed_out, fn(r) { kill(r.pid) })
  let timeout_results = list.map(timed_out, fn(r) { timeout_result(r.index) })
  #(pending, still_running, list.append(timeout_results, pending_emit))
}

fn timeout_result(index: Int) -> IndexedResult {
  let failure = hook_failure("timeout", "test timed out")
  let result =
    TestResult(
      name: "<timeout>",
      full_name: ["<timeout>"],
      status: TimedOut,
      duration_ms: 0,
      tags: [],
      failures: [failure],
      kind: Unit,
    )
  IndexedResult(index: index, result: result)
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
  before_each_hooks: List(fn(context) -> Result(context, String)),
  after_each_hooks: List(fn(context) -> Result(Nil, String)),
  failures_rev: List(AssertionFailure),
  node: Node(context),
) -> TestResult {
  // Fallback to sequential single-test logic by reusing existing code path.
  case node {
    Test(name, tags, kind, run, timeout_ms) -> {
      let full_name = list.append(scope, [name])
      let all_tags = list.append(inherited_tags, tags)
      let start = timing.now_ms()

      let #(ctx_after_setup, setup_status, setup_failures) =
        run_before_each_list(config, scope, context, before_each_hooks, [])

      let assertion = case setup_status {
        SetupFailed -> AssertionFailed(head_failure_or_unknown(setup_failures))
        _ ->
          run_in_sandbox(config, timeout_ms, fn() {
            case run(ctx_after_setup) {
              Ok(a) -> a
              Error(message) -> AssertionFailed(hook_failure("error", message))
            }
          })
      }

      let #(status, failures) =
        assertion_to_status_and_failures(
          assertion,
          failures_rev,
          setup_failures,
        )

      let #(final_status, final_failures) =
        run_after_each_list(
          config,
          scope,
          ctx_after_setup,
          after_each_hooks,
          status,
          failures,
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
  before_each_hooks: List(fn(context) -> Result(context, String)),
  after_each_hooks: List(fn(context) -> Result(Nil, String)),
  tests: List(Node(context)),
  failures_rev: List(AssertionFailure),
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case tests {
    [] -> acc_rev
    [Test(name, tags, kind, run, timeout_ms), ..rest] -> {
      let full_name = list.append(scope, [name])
      let all_tags = list.append(inherited_tags, tags)
      let start = timing.now_ms()

      let #(ctx_after_setup, setup_status, setup_failures) =
        run_before_each_list(config, scope, context, before_each_hooks, [])

      let assertion = case setup_status {
        SetupFailed -> AssertionFailed(head_failure_or_unknown(setup_failures))
        _ ->
          run_in_sandbox(config, timeout_ms, fn() {
            case run(ctx_after_setup) {
              Ok(a) -> a
              Error(message) -> AssertionFailed(hook_failure("error", message))
            }
          })
      }

      let #(status, failures) =
        assertion_to_status_and_failures(
          assertion,
          failures_rev,
          setup_failures,
        )

      let #(final_status, final_failures) =
        run_after_each_list(
          config,
          scope,
          ctx_after_setup,
          after_each_hooks,
          status,
          failures,
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

      run_tests_sequentially(
        config,
        scope,
        inherited_tags,
        context,
        before_each_hooks,
        after_each_hooks,
        rest,
        failures_rev,
        [result, ..acc_rev],
      )
    }

    [_other, ..rest] ->
      run_tests_sequentially(
        config,
        scope,
        inherited_tags,
        context,
        before_each_hooks,
        after_each_hooks,
        rest,
        failures_rev,
        acc_rev,
      )
  }
}

fn run_child_groups_sequentially(
  config: ParallelConfig,
  scope: List(String),
  inherited_tags: List(String),
  context: context,
  before_each_hooks: List(fn(context) -> Result(context, String)),
  after_each_hooks: List(fn(context) -> Result(Nil, String)),
  groups: List(Node(context)),
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case groups {
    [] -> acc_rev
    [group_node, ..rest] -> {
      let next_rev =
        execute_node(
          config,
          scope,
          inherited_tags,
          context,
          before_each_hooks,
          after_each_hooks,
          group_node,
          acc_rev,
        )
      run_child_groups_sequentially(
        config,
        scope,
        inherited_tags,
        context,
        before_each_hooks,
        after_each_hooks,
        rest,
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

fn hook_failure(operator: String, message: String) -> AssertionFailure {
  AssertionFailure(operator: operator, message: message, payload: None)
}

fn head_failure_or_unknown(
  failures_rev: List(AssertionFailure),
) -> AssertionFailure {
  case failures_rev {
    [f, ..] -> f
    [] -> hook_failure("before_each", "setup failed")
  }
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
      Passed,
      list.append(setup_failures_rev, inherited_failures_rev),
    )
  }
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

// =============================================================================
// Reporter variant
// =============================================================================

fn execute_node_with_reporter(
  config: ParallelConfig,
  scope: List(String),
  inherited_tags: List(String),
  context: context,
  inherited_before_each: List(fn(context) -> Result(context, String)),
  inherited_after_each: List(fn(context) -> Result(Nil, String)),
  node: Node(context),
  reporter0: Reporter,
  total: Int,
  completed: Int,
  acc_rev: List(TestResult),
) -> #(List(TestResult), Reporter, Int) {
  let results =
    execute_node(
      config,
      scope,
      inherited_tags,
      context,
      inherited_before_each,
      inherited_after_each,
      node,
      acc_rev,
    )
  let #(next_completed, next_reporter) =
    emit_test_finished_events(results, completed, total, reporter0)
  #(results, next_reporter, next_completed)
}

fn emit_test_finished_events(
  results_rev: List(TestResult),
  completed: Int,
  total: Int,
  reporter: Reporter,
) -> #(Int, Reporter) {
  case list.reverse(results_rev) {
    [] -> #(completed, reporter)
    [r, ..rest] ->
      emit_test_finished_events_from_list(rest, completed, total, reporter, r)
  }
}

fn emit_test_finished_events_from_list(
  remaining: List(TestResult),
  completed: Int,
  total: Int,
  reporter: Reporter,
  current: TestResult,
) -> #(Int, Reporter) {
  let next_completed = completed + 1
  let reporter1 =
    handle_event(
      reporter,
      reporter_types.TestFinished(next_completed, total, current),
    )
  case remaining {
    [] -> #(next_completed, reporter1)
    [r, ..rest] ->
      emit_test_finished_events_from_list(
        rest,
        next_completed,
        total,
        reporter1,
        r,
      )
  }
}
