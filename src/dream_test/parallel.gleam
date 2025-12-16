//// Parallel suite execution with configurable concurrency.
////
//// This module executes `types.TestSuite(ctx)` with:
//// - process isolation (each test runs in its own BEAM process)
//// - timeout protection
//// - parallelism up to max_concurrency
//// - deterministic result ordering (based on traversal order)
////
//// It does NOT provide a list-based `run_parallel` mode; suites are the only
//// execution unit.

import dream_test/reporter/api.{type Reporter, handle_event}
import dream_test/reporter/types as reporter_types
import dream_test/timing
import dream_test/types.{
  type AssertionFailure, type AssertionResult, type Status, type SuiteTestCase,
  type TestKind, type TestResult, type TestSuite, type TestSuiteItem,
  AssertionFailed, AssertionOk, AssertionSkipped, Failed, Passed, SetupFailed,
  Skipped, SuiteGroup, SuiteTest, TestResult, TimedOut, Unit,
}
import gleam/erlang/process.{
  type Pid, type Selector, type Subject, kill, monitor, new_selector,
  new_subject, select, select_monitors, selector_receive, send, spawn_unlinked,
}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string

/// Configuration for parallel execution.
pub type ParallelConfig {
  ParallelConfig(max_concurrency: Int, default_timeout_ms: Int)
}

pub fn default_config() -> ParallelConfig {
  ParallelConfig(max_concurrency: 4, default_timeout_ms: 5000)
}

/// Run a suite in parallel.
///
/// Nested groups are processed after the current group's tests complete.
pub fn run_suite_parallel(
  config: ParallelConfig,
  suite: TestSuite(ctx),
) -> List(TestResult) {
  // Root suites always provide a before_all. For `unit.describe`, it's defaulted to Ok(Nil).
  let assert Some(setup) = suite.before_all as "root suite missing before_all"
  case setup() {
    Error(message) -> build_before_all_failed_results(suite, message)
    Ok(ctx) -> {
      let prepared = prepare_suite(suite, Some(ctx), [], [], [], 0, [])
      run_prepared_with_groups_and_after_all(config, prepared, suite, ctx)
    }
  }
}

/// Run a suite and emit reporter events.
///
/// This is intended to drive progress indicators. Events are emitted in
/// completion order after results are available.
pub fn run_suite_parallel_with_events(
  config: ParallelConfig,
  suite: TestSuite(ctx),
  on_event: fn(reporter_types.ReporterEvent) -> Nil,
) -> List(TestResult) {
  let total = count_tests_in_suite(suite)
  on_event(reporter_types.RunStarted(total))

  let results = run_suite_parallel(config, suite)
  let completed = emit_finished_events(results, total, 0, on_event)

  on_event(reporter_types.RunFinished(completed, total))
  results
}

/// Run a suite in parallel while driving a reporter as results become available.
///
/// This is used by `runner` to provide truly live reporting without requiring
/// the caller to provide an event handler.
pub fn run_suite_parallel_with_reporter(
  config: ParallelConfig,
  suite: TestSuite(ctx),
  reporter0: Reporter,
  total: Int,
  completed: Int,
) -> #(List(TestResult), Int, Reporter) {
  // Root suites always provide a before_all. For `unit.describe`, it's defaulted to Ok(Nil).
  let assert Some(setup) = suite.before_all as "root suite missing before_all"

  let reporter1 = case suite.has_user_before_all {
    True ->
      handle_event(
        reporter0,
        reporter_types.HookStarted(
          kind: reporter_types.BeforeAll,
          scope: [suite.name],
          test_name: None,
        ),
      )
    False -> reporter0
  }

  case setup() {
    Error(message) -> {
      let reporter2 = case suite.has_user_before_all {
        True ->
          handle_event(
            reporter1,
            reporter_types.HookFinished(
              kind: reporter_types.BeforeAll,
              scope: [suite.name],
              test_name: None,
              outcome: reporter_types.HookError(message),
            ),
          )
        False -> reporter1
      }

      let results = build_before_all_failed_results(suite, message)
      let #(completed2, reporter3) =
        emit_results_as_test_finished_events(
          results,
          total,
          completed,
          reporter2,
        )

      #(results, completed2, reporter3)
    }

    Ok(ctx) -> {
      let reporter2 = case suite.has_user_before_all {
        True ->
          handle_event(
            reporter1,
            reporter_types.HookFinished(
              kind: reporter_types.BeforeAll,
              scope: [suite.name],
              test_name: None,
              outcome: reporter_types.HookOk,
            ),
          )
        False -> reporter1
      }

      let prepared = prepare_suite(suite, Some(ctx), [], [], [], 0, [])
      let #(test_results, completed2, reporter3) =
        run_prepared_with_groups_and_after_all_with_reporter(
          config,
          prepared,
          suite,
          ctx,
          reporter2,
          total,
          completed,
        )

      #(test_results, completed2, reporter3)
    }
  }
}

fn count_tests_in_suite(suite: TestSuite(ctx)) -> Int {
  suite
  |> collect_all_tests([], [])
  |> list.length
}

fn emit_finished_events(
  results: List(TestResult),
  total: Int,
  completed: Int,
  on_event: fn(reporter_types.ReporterEvent) -> Nil,
) -> Int {
  case results {
    [] -> completed
    [result, ..rest] -> {
      case result.name == "<after_all>" {
        True -> emit_finished_events(rest, total, completed, on_event)
        False -> {
          let next = completed + 1
          on_event(reporter_types.TestFinished(next, total, result))
          emit_finished_events(rest, total, next, on_event)
        }
      }
    }
  }
}

fn run_prepared_with_groups_and_after_all(
  config: ParallelConfig,
  prepared: PreparedSuite(ctx),
  suite: TestSuite(ctx),
  ctx: ctx,
) -> List(TestResult) {
  let results = run_prepared_tests(config, prepared.tests)
  let group_results =
    run_groups_sequentially(config, prepared.groups, Some(ctx), [])
  let after_all_results =
    run_after_all_hooks([suite.name], ctx, suite.after_all)
  list.append(list.append(results, group_results), after_all_results)
}

fn run_prepared_with_groups_and_after_all_with_reporter(
  config: ParallelConfig,
  prepared: PreparedSuite(ctx),
  suite: TestSuite(ctx),
  ctx: ctx,
  reporter0: Reporter,
  total: Int,
  completed: Int,
) -> #(List(TestResult), Int, Reporter) {
  let #(results, completed1, reporter1) =
    run_prepared_tests_with_reporter(
      config,
      prepared.tests,
      reporter0,
      total,
      completed,
    )

  let #(group_results, completed2, reporter2, stop_message) =
    run_groups_sequentially_with_reporter(
      config,
      prepared.groups,
      Some(ctx),
      reporter1,
      total,
      completed1,
      [],
    )

  case stop_message {
    Some(_message) -> {
      // A nested after_all failed. Stop further work in this suite.
      let #(remaining_after_all, reporter3) =
        run_after_all_hooks_with_reporter(
          [suite.name],
          ctx,
          suite.after_all,
          reporter2,
        )
      let all =
        list.append(list.append(results, group_results), remaining_after_all)
      #(all, completed2, reporter3)
    }

    None -> {
      let #(after_all_results, reporter3) =
        run_after_all_hooks_with_reporter(
          [suite.name],
          ctx,
          suite.after_all,
          reporter2,
        )

      let all =
        list.append(list.append(results, group_results), after_all_results)
      #(all, completed2, reporter3)
    }
  }
}

fn emit_results_as_test_finished_events(
  results: List(TestResult),
  total: Int,
  completed: Int,
  reporter: Reporter,
) -> #(Int, Reporter) {
  case results {
    [] -> #(completed, reporter)
    [result, ..rest] ->
      case result.name == "<after_all>" {
        True ->
          emit_results_as_test_finished_events(rest, total, completed, reporter)
        False -> {
          let next_completed = completed + 1
          let next_reporter =
            handle_event(
              reporter,
              reporter_types.TestFinished(next_completed, total, result),
            )
          emit_results_as_test_finished_events(
            rest,
            total,
            next_completed,
            next_reporter,
          )
        }
      }
  }
}

fn build_before_all_failed_results(
  suite: TestSuite(ctx),
  message: String,
) -> List(TestResult) {
  collect_all_tests(suite, [], [])
  |> list.map(fn(pair) {
    let #(full_name, test_case) = pair
    TestResult(
      name: test_case.name,
      full_name: full_name,
      status: SetupFailed,
      duration_ms: 0,
      tags: test_case.tags,
      failures: [
        types.AssertionFailure(
          operator: "before_all",
          message: message,
          payload: None,
        ),
      ],
      kind: test_case.kind,
    )
  })
}

fn collect_all_tests(
  suite: TestSuite(ctx),
  prefix: List(String),
  accumulated: List(#(List(String), SuiteTestCase(ctx))),
) -> List(#(List(String), SuiteTestCase(ctx))) {
  let suite_prefix = list.append(prefix, [suite.name])
  collect_all_tests_from_items(suite.items, suite_prefix, accumulated)
}

fn collect_all_tests_from_items(
  items: List(TestSuiteItem(ctx)),
  prefix: List(String),
  accumulated: List(#(List(String), SuiteTestCase(ctx))),
) -> List(#(List(String), SuiteTestCase(ctx))) {
  case items {
    [] -> list.reverse(accumulated)
    [item, ..rest] ->
      case item {
        SuiteTest(test_case) -> {
          let full_name = list.append(prefix, [test_case.name])
          collect_all_tests_from_items(rest, prefix, [
            #(full_name, test_case),
            ..accumulated
          ])
        }
        SuiteGroup(group_suite) -> {
          let next = collect_all_tests(group_suite, prefix, accumulated)
          collect_all_tests_from_items(rest, prefix, next)
        }
      }
  }
}

fn run_after_all_hooks(
  suite_prefix: List(String),
  ctx: ctx,
  hooks: List(fn(ctx) -> Result(Nil, String)),
) -> List(TestResult) {
  run_after_all_from_list(suite_prefix, ctx, hooks)
}

fn run_after_all_hooks_with_reporter(
  suite_prefix: List(String),
  ctx: ctx,
  hooks: List(fn(ctx) -> Result(Nil, String)),
  reporter0: Reporter,
) -> #(List(TestResult), Reporter) {
  case hooks {
    [] -> #([], reporter0)
    _ -> {
      let reporter1 =
        handle_event(
          reporter0,
          reporter_types.HookStarted(
            kind: reporter_types.AfterAll,
            scope: suite_prefix,
            test_name: None,
          ),
        )

      let #(results, reporter2, outcome) =
        run_after_all_from_list_with_reporter(
          suite_prefix,
          ctx,
          hooks,
          reporter1,
        )

      let reporter3 =
        handle_event(
          reporter2,
          reporter_types.HookFinished(
            kind: reporter_types.AfterAll,
            scope: suite_prefix,
            test_name: None,
            outcome: outcome,
          ),
        )

      #(results, reporter3)
    }
  }
}

fn run_after_all_from_list(
  suite_prefix: List(String),
  ctx: ctx,
  hooks: List(fn(ctx) -> Result(Nil, String)),
) -> List(TestResult) {
  case hooks {
    [] -> []
    [hook, ..rest] ->
      case hook(ctx) {
        Ok(_) -> run_after_all_from_list(suite_prefix, ctx, rest)
        Error(message) -> [
          TestResult(
            name: "<after_all>",
            full_name: list.append(suite_prefix, ["<after_all>"]),
            status: Failed,
            duration_ms: 0,
            tags: [],
            failures: [
              types.AssertionFailure(
                operator: "after_all",
                message: message,
                payload: None,
              ),
            ],
            kind: Unit,
          ),
        ]
      }
  }
}

fn run_after_all_from_list_with_reporter(
  suite_prefix: List(String),
  ctx: ctx,
  hooks: List(fn(ctx) -> Result(Nil, String)),
  reporter: Reporter,
) -> #(List(TestResult), Reporter, reporter_types.HookOutcome) {
  case hooks {
    [] -> #([], reporter, reporter_types.HookOk)
    [hook, ..rest] ->
      case hook(ctx) {
        Ok(_) ->
          run_after_all_from_list_with_reporter(
            suite_prefix,
            ctx,
            rest,
            reporter,
          )
        Error(message) -> #(
          [
            TestResult(
              name: "<after_all>",
              full_name: list.append(suite_prefix, ["<after_all>"]),
              status: Failed,
              duration_ms: 0,
              tags: [],
              failures: [
                types.AssertionFailure(
                  operator: "after_all",
                  message: message,
                  payload: None,
                ),
              ],
              kind: Unit,
            ),
          ],
          reporter,
          reporter_types.HookError(message),
        )
      }
  }
}

// =============================================================================
// Suite traversal (flatten into runnable tests + nested suites)
// =============================================================================

type PreparedSuite(ctx) {
  PreparedSuite(
    tests: List(PreparedTest(ctx)),
    groups: List(PreparedGroup(ctx)),
  )
}

type PreparedTest(ctx) {
  PreparedTest(
    index: Int,
    full_name: List(String),
    initial_context: Option(ctx),
    before_each: List(fn(ctx) -> Result(ctx, String)),
    after_each: List(fn(ctx) -> Result(Nil, String)),
    test_case: SuiteTestCase(ctx),
  )
}

type PreparedGroup(ctx) {
  PreparedGroup(
    suite: TestSuite(ctx),
    initial_context: Option(ctx),
    name_prefix: List(String),
    before_each: List(fn(ctx) -> Result(ctx, String)),
    after_each: List(fn(ctx) -> Result(Nil, String)),
    index_base: Int,
  )
}

fn prepare_suite(
  suite: TestSuite(ctx),
  initial_context: Option(ctx),
  name_prefix: List(String),
  inherited_before_each: List(fn(ctx) -> Result(ctx, String)),
  inherited_after_each: List(fn(ctx) -> Result(Nil, String)),
  index: Int,
  accumulated_tests: List(PreparedTest(ctx)),
) -> PreparedSuite(ctx) {
  // Note: we do NOT execute before_all here; we do it when preparing tests for this suite.
  let #(tests, _next_index) =
    prepare_items(
      suite,
      suite.items,
      initial_context,
      list.append(inherited_before_each, suite.before_each),
      list.append(suite.after_each, inherited_after_each),
      name_prefix,
      index,
      accumulated_tests,
    )
  let groups =
    collect_groups(
      suite,
      suite.items,
      initial_context,
      name_prefix,
      inherited_before_each,
      inherited_after_each,
      index,
      [],
    )
  PreparedSuite(tests: tests, groups: groups)
}

fn prepare_items(
  suite: TestSuite(ctx),
  items: List(TestSuiteItem(ctx)),
  initial_context: Option(ctx),
  before_each: List(fn(ctx) -> Result(ctx, String)),
  after_each: List(fn(ctx) -> Result(Nil, String)),
  name_prefix: List(String),
  index: Int,
  accumulated: List(PreparedTest(ctx)),
) -> #(List(PreparedTest(ctx)), Int) {
  case items {
    [] -> #(list.reverse(accumulated), index)
    [item, ..rest] ->
      case item {
        SuiteTest(test_case) -> {
          let full_name = list.append(name_prefix, [suite.name, test_case.name])
          let prepared =
            PreparedTest(
              index: index,
              full_name: full_name,
              initial_context: initial_context,
              before_each: before_each,
              after_each: after_each,
              test_case: test_case,
            )
          prepare_items(
            suite,
            rest,
            initial_context,
            before_each,
            after_each,
            name_prefix,
            index + 1,
            [prepared, ..accumulated],
          )
        }
        SuiteGroup(_) ->
          prepare_items(
            suite,
            rest,
            initial_context,
            before_each,
            after_each,
            name_prefix,
            index,
            accumulated,
          )
      }
  }
}

fn collect_groups(
  suite: TestSuite(ctx),
  items: List(TestSuiteItem(ctx)),
  initial_context: Option(ctx),
  name_prefix: List(String),
  inherited_before_each: List(fn(ctx) -> Result(ctx, String)),
  inherited_after_each: List(fn(ctx) -> Result(Nil, String)),
  index_base: Int,
  accumulated: List(PreparedGroup(ctx)),
) -> List(PreparedGroup(ctx)) {
  case items {
    [] -> list.reverse(accumulated)
    [item, ..rest] ->
      case item {
        SuiteGroup(group_suite) -> {
          let group =
            PreparedGroup(
              suite: group_suite,
              initial_context: initial_context,
              name_prefix: list.append(name_prefix, [suite.name]),
              before_each: list.append(inherited_before_each, suite.before_each),
              after_each: list.append(suite.after_each, inherited_after_each),
              index_base: index_base,
            )
          collect_groups(
            suite,
            rest,
            initial_context,
            name_prefix,
            inherited_before_each,
            inherited_after_each,
            index_base,
            [group, ..accumulated],
          )
        }
        _ ->
          collect_groups(
            suite,
            rest,
            initial_context,
            name_prefix,
            inherited_before_each,
            inherited_after_each,
            index_base,
            accumulated,
          )
      }
  }
}

// =============================================================================
// Parallel execution of prepared tests
// =============================================================================

type ExecutionState(ctx) {
  ExecutionState(
    pending: List(PreparedTest(ctx)),
    running: List(RunningTest),
    completed: List(IndexedResult),
    results_subject: Subject(WorkerMessage),
    config: ParallelConfig,
  )
}

type RunningTest {
  RunningTest(
    index: Int,
    worker_pid: Pid,
    worker_monitor: process.Monitor,
    deadline_ms: Int,
    full_name: List(String),
    kind: TestKind,
    tags: List(String),
  )
}

type IndexedResult {
  IndexedResult(index: Int, result: TestResult)
}

type WorkerMessage {
  WorkerCompleted(index: Int, result: TestResult)
  WorkerCrashed(pid: Pid, reason: String)
  HookEvent(event: reporter_types.ReporterEvent)
}

fn run_prepared_tests(
  config: ParallelConfig,
  tests: List(PreparedTest(ctx)),
) -> List(TestResult) {
  case tests {
    [] -> []
    _ -> {
      let subject = new_subject()
      let state =
        ExecutionState(
          pending: tests,
          running: [],
          completed: [],
          results_subject: subject,
          config: config,
        )
      let final = execute_loop(state)
      sort_results(final.completed)
    }
  }
}

fn run_prepared_tests_with_reporter(
  config: ParallelConfig,
  tests: List(PreparedTest(ctx)),
  reporter0: Reporter,
  total: Int,
  completed: Int,
) -> #(List(TestResult), Int, Reporter) {
  case tests {
    [] -> #([], completed, reporter0)
    _ -> {
      let subject = new_subject()
      let start_index = min_test_index(tests, 0)
      let state =
        ExecutionStateWithReporter(
          pending: tests,
          running: [],
          completed_all: [],
          pending_emit: [],
          results_subject: subject,
          config: config,
          reporter: reporter0,
          completed_count: completed,
          total: total,
          next_emit_index: start_index,
        )
      let final = execute_loop_with_reporter(state)
      let results = sort_results(final.completed_all)
      #(results, final.completed_count, final.reporter)
    }
  }
}

type ExecutionStateWithReporter(ctx) {
  ExecutionStateWithReporter(
    pending: List(PreparedTest(ctx)),
    running: List(RunningTest),
    completed_all: List(IndexedResult),
    pending_emit: List(IndexedResult),
    results_subject: Subject(WorkerMessage),
    config: ParallelConfig,
    reporter: Reporter,
    completed_count: Int,
    total: Int,
    next_emit_index: Int,
  )
}

fn execute_loop_with_reporter(
  state: ExecutionStateWithReporter(ctx),
) -> ExecutionStateWithReporter(ctx) {
  let state_with_workers = start_workers_up_to_limit_with_reporter(state)
  case
    list.is_empty(state_with_workers.pending)
    && list.is_empty(state_with_workers.running)
  {
    True -> state_with_workers
    False ->
      execute_loop_with_reporter(wait_for_event_with_reporter(
        state_with_workers,
      ))
  }
}

fn start_workers_up_to_limit_with_reporter(
  state: ExecutionStateWithReporter(ctx),
) -> ExecutionStateWithReporter(ctx) {
  let slots = state.config.max_concurrency - list.length(state.running)
  case slots > 0 && !list.is_empty(state.pending) {
    False -> state
    True ->
      start_workers_up_to_limit_with_reporter(start_next_worker_with_reporter(
        state,
      ))
  }
}

fn start_next_worker_with_reporter(
  state: ExecutionStateWithReporter(ctx),
) -> ExecutionStateWithReporter(ctx) {
  case state.pending {
    [] -> state
    [next, ..rest] -> {
      let #(running, _monitor) =
        spawn_worker(state.results_subject, state.config, next)
      ExecutionStateWithReporter(..state, pending: rest, running: [
        running,
        ..state.running
      ])
    }
  }
}

fn wait_for_event_with_reporter(
  state: ExecutionStateWithReporter(ctx),
) -> ExecutionStateWithReporter(ctx) {
  let selector = build_selector(state.results_subject)
  let next_timeout = next_deadline_timeout(state.running, 1000)
  case selector_receive(selector, next_timeout) {
    Ok(event) -> handle_worker_message_with_reporter(state, event)
    Error(Nil) -> handle_timeouts_with_reporter(state)
  }
}

fn handle_worker_message_with_reporter(
  state: ExecutionStateWithReporter(ctx),
  message: WorkerMessage,
) -> ExecutionStateWithReporter(ctx) {
  case message {
    HookEvent(event) ->
      ExecutionStateWithReporter(
        ..state,
        reporter: handle_event(state.reporter, event),
      )

    WorkerCompleted(index, result) -> {
      let indexed = IndexedResult(index: index, result: result)
      let state1 =
        ExecutionStateWithReporter(
          ..state,
          running: remove_running_by_index(state.running, index),
          completed_all: [indexed, ..state.completed_all],
          pending_emit: [indexed, ..state.pending_emit],
        )
      emit_ready_results(state1)
    }

    WorkerCrashed(pid, reason) -> {
      case find_running_by_pid(state.running, pid) {
        Some(running) -> {
          let failure =
            types.AssertionFailure(
              operator: "crash",
              message: reason,
              payload: None,
            )
          let result =
            TestResult(
              name: last_name(running.full_name),
              full_name: running.full_name,
              status: Failed,
              duration_ms: 0,
              tags: running.tags,
              failures: [failure],
              kind: running.kind,
            )
          let indexed = IndexedResult(index: running.index, result: result)
          let state1 =
            ExecutionStateWithReporter(
              ..state,
              running: remove_running_by_pid(state.running, pid),
              completed_all: [indexed, ..state.completed_all],
              pending_emit: [indexed, ..state.pending_emit],
            )
          emit_ready_results(state1)
        }
        None -> state
      }
    }
  }
}

fn handle_timeouts_with_reporter(
  state: ExecutionStateWithReporter(ctx),
) -> ExecutionStateWithReporter(ctx) {
  let now = timing.now_ms()
  let #(timed_out, still_running) =
    partition_timeouts(state.running, now, [], [])
  kill_all(timed_out)
  let timeout_results = list.map(timed_out, make_timeout_result)
  let state1 =
    ExecutionStateWithReporter(
      ..state,
      running: still_running,
      completed_all: list.append(timeout_results, state.completed_all),
      pending_emit: list.append(timeout_results, state.pending_emit),
    )
  emit_ready_results(state1)
}

fn emit_ready_results(
  state: ExecutionStateWithReporter(ctx),
) -> ExecutionStateWithReporter(ctx) {
  let #(maybe_result, remaining) =
    take_indexed_result(state.next_emit_index, state.pending_emit, [])
  case maybe_result {
    None -> ExecutionStateWithReporter(..state, pending_emit: remaining)
    Some(indexed) -> {
      let next_completed = state.completed_count + 1
      let next_reporter =
        handle_event(
          state.reporter,
          reporter_types.TestFinished(
            next_completed,
            state.total,
            indexed.result,
          ),
        )
      emit_ready_results(
        ExecutionStateWithReporter(
          ..state,
          pending_emit: remaining,
          reporter: next_reporter,
          completed_count: next_completed,
          next_emit_index: state.next_emit_index + 1,
        ),
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

fn min_test_index(tests: List(PreparedTest(ctx)), fallback: Int) -> Int {
  case tests {
    [] -> fallback
    [t, ..rest] -> min_test_index_from_list(rest, t.index)
  }
}

fn min_test_index_from_list(tests: List(PreparedTest(ctx)), current: Int) -> Int {
  case tests {
    [] -> current
    [t, ..rest] ->
      case t.index < current {
        True -> min_test_index_from_list(rest, t.index)
        False -> min_test_index_from_list(rest, current)
      }
  }
}

fn execute_loop(state: ExecutionState(ctx)) -> ExecutionState(ctx) {
  let state_with_workers = start_workers_up_to_limit(state)
  case
    list.is_empty(state_with_workers.pending)
    && list.is_empty(state_with_workers.running)
  {
    True -> state_with_workers
    False -> execute_loop(wait_for_event(state_with_workers))
  }
}

fn start_workers_up_to_limit(state: ExecutionState(ctx)) -> ExecutionState(ctx) {
  let slots = state.config.max_concurrency - list.length(state.running)
  case slots > 0 && !list.is_empty(state.pending) {
    False -> state
    True -> start_workers_up_to_limit(start_next_worker(state))
  }
}

fn start_next_worker(state: ExecutionState(ctx)) -> ExecutionState(ctx) {
  case state.pending {
    [] -> state
    [next, ..rest] -> {
      let #(running, _monitor) =
        spawn_worker(state.results_subject, state.config, next)
      ExecutionState(..state, pending: rest, running: [running, ..state.running])
    }
  }
}

fn spawn_worker(
  results_subject: Subject(WorkerMessage),
  config: ParallelConfig,
  prepared: PreparedTest(ctx),
) -> #(RunningTest, process.Monitor) {
  let pid =
    spawn_unlinked(fn() {
      run_prepared_in_worker(results_subject, config, prepared)
    })
  let mon = monitor(pid)
  let timeout = case prepared.test_case.timeout_ms {
    Some(ms) -> ms
    None -> config.default_timeout_ms
  }
  let deadline_ms = timing.now_ms() + timeout
  let running =
    RunningTest(
      index: prepared.index,
      worker_pid: pid,
      worker_monitor: mon,
      deadline_ms: deadline_ms,
      full_name: prepared.full_name,
      kind: prepared.test_case.kind,
      tags: prepared.test_case.tags,
    )
  #(running, mon)
}

fn run_prepared_in_worker(
  reply_to: Subject(WorkerMessage),
  _config: ParallelConfig,
  prepared: PreparedTest(ctx),
) -> Nil {
  let start_time = timing.now_ms()
  let result = run_test_in_worker(prepared, reply_to)
  let duration_ms = timing.now_ms() - start_time
  send(
    reply_to,
    WorkerCompleted(
      prepared.index,
      TestResult(..result, duration_ms: duration_ms),
    ),
  )
}

fn run_test_in_worker(
  prepared: PreparedTest(ctx),
  reply_to: Subject(WorkerMessage),
) -> TestResult {
  // Establish a baseline context.
  let ctx = case prepared.initial_context {
    Some(value) -> value
    None ->
      panic as "missing before_all context; root suite must define before_all"
  }
  let scope = drop_last_segment(prepared.full_name, [])
  let test_name = last_name(prepared.full_name)

  case list.is_empty(prepared.before_each) {
    True -> Nil
    False ->
      send(
        reply_to,
        HookEvent(reporter_types.HookStarted(
          kind: reporter_types.BeforeEach,
          scope: scope,
          test_name: Some(test_name),
        )),
      )
  }

  let #(ctx_after_setup, setup_status, setup_failure, before_each_outcome) =
    run_before_each_chain_with_outcome(ctx, prepared.before_each)

  case list.is_empty(prepared.before_each) {
    True -> Nil
    False ->
      send(
        reply_to,
        HookEvent(reporter_types.HookFinished(
          kind: reporter_types.BeforeEach,
          scope: scope,
          test_name: Some(test_name),
          outcome: before_each_outcome,
        )),
      )
  }

  let #(test_status, failures) = case setup_status {
    SetupFailed -> #(SetupFailed, [setup_failure])
    _ -> run_test_body(ctx_after_setup, prepared.test_case)
  }

  case list.is_empty(prepared.after_each) {
    True -> Nil
    False ->
      send(
        reply_to,
        HookEvent(reporter_types.HookStarted(
          kind: reporter_types.AfterEach,
          scope: scope,
          test_name: Some(test_name),
        )),
      )
  }

  let #(final_status, final_failures) =
    run_after_each_chain(
      ctx_after_setup,
      prepared.after_each,
      test_status,
      failures,
    )

  let after_each_outcome =
    extract_after_each_outcome(final_status, final_failures, failures)

  case list.is_empty(prepared.after_each) {
    True -> Nil
    False ->
      send(
        reply_to,
        HookEvent(reporter_types.HookFinished(
          kind: reporter_types.AfterEach,
          scope: scope,
          test_name: Some(test_name),
          outcome: after_each_outcome,
        )),
      )
  }

  TestResult(
    name: last_name(prepared.full_name),
    full_name: prepared.full_name,
    status: final_status,
    duration_ms: 0,
    tags: prepared.test_case.tags,
    failures: final_failures,
    kind: prepared.test_case.kind,
  )
}

fn last_name(full_name: List(String)) -> String {
  case list.reverse(full_name) {
    [last, ..] -> last
    [] -> ""
  }
}

fn drop_last_segment(
  full_name: List(String),
  rev_acc: List(String),
) -> List(String) {
  case full_name {
    [] -> []
    [_] -> list.reverse(rev_acc)
    [h, ..t] -> drop_last_segment(t, [h, ..rev_acc])
  }
}

fn run_before_each_chain_with_outcome(
  ctx: ctx,
  hooks: List(fn(ctx) -> Result(ctx, String)),
) -> #(ctx, Status, AssertionFailure, reporter_types.HookOutcome) {
  let #(next_ctx, status, failure) = run_before_each_from_list(ctx, hooks)
  case status {
    SetupFailed -> #(
      next_ctx,
      status,
      failure,
      reporter_types.HookError(failure.message),
    )
    _ -> #(next_ctx, status, failure, reporter_types.HookOk)
  }
}

fn run_before_each_from_list(
  ctx: ctx,
  hooks: List(fn(ctx) -> Result(ctx, String)),
) -> #(ctx, Status, AssertionFailure) {
  case hooks {
    [] -> #(
      ctx,
      Passed,
      types.AssertionFailure(operator: "", message: "", payload: None),
    )
    [hook, ..rest] ->
      case hook(ctx) {
        Ok(next_ctx) -> run_before_each_from_list(next_ctx, rest)
        Error(message) -> #(
          ctx,
          SetupFailed,
          types.AssertionFailure(
            operator: "setup",
            message: message,
            payload: None,
          ),
        )
      }
  }
}

fn run_test_body(
  ctx: ctx,
  test_case: SuiteTestCase(ctx),
) -> #(Status, List(AssertionFailure)) {
  case test_case.run(ctx) {
    Ok(assertion_result) -> assertion_to_status(assertion_result)
    Error(message) -> #(Failed, [
      types.AssertionFailure(operator: "error", message: message, payload: None),
    ])
  }
}

fn assertion_to_status(
  result: AssertionResult,
) -> #(Status, List(AssertionFailure)) {
  case result {
    AssertionOk -> #(Passed, [])
    AssertionSkipped -> #(Skipped, [])
    AssertionFailed(failure) -> #(Failed, [failure])
  }
}

fn run_after_each_chain(
  ctx: ctx,
  hooks: List(fn(ctx) -> Result(Nil, String)),
  status: Status,
  failures: List(AssertionFailure),
) -> #(Status, List(AssertionFailure)) {
  case hooks {
    [] -> #(status, failures)
    [hook, ..rest] ->
      case hook(ctx) {
        Ok(_) -> run_after_each_chain(ctx, rest, status, failures)
        Error(message) -> {
          let failure =
            types.AssertionFailure(
              operator: "teardown",
              message: message,
              payload: None,
            )
          #(Failed, [failure, ..failures])
        }
      }
  }
}

fn extract_after_each_outcome(
  _final_status: Status,
  final_failures: List(AssertionFailure),
  failures_before_after_each: List(AssertionFailure),
) -> reporter_types.HookOutcome {
  // If after_each added at least one failure, treat that as the hook error.
  case list.length(final_failures) > list.length(failures_before_after_each) {
    False -> reporter_types.HookOk
    True ->
      case final_failures {
        [failure, ..] -> reporter_types.HookError(failure.message)
        [] -> reporter_types.HookError("after_each failed")
      }
  }
}

fn wait_for_event(state: ExecutionState(ctx)) -> ExecutionState(ctx) {
  let selector = build_selector(state.results_subject)
  // compute next deadline
  let next_timeout = next_deadline_timeout(state.running, 1000)
  case selector_receive(selector, next_timeout) {
    Ok(event) -> handle_worker_message(state, event)
    Error(Nil) -> handle_timeouts(state)
  }
}

fn build_selector(subject: Subject(WorkerMessage)) -> Selector(WorkerMessage) {
  new_selector()
  |> select(subject)
  |> select_monitors(map_down_to_worker_message)
}

fn map_down_to_worker_message(down: process.Down) -> WorkerMessage {
  case down {
    process.ProcessDown(_, pid, reason) ->
      WorkerCrashed(pid, format_exit_reason(reason))
    process.PortDown(_, _, reason) ->
      WorkerCrashed(process.self(), format_exit_reason(reason))
  }
}

fn format_exit_reason(reason: process.ExitReason) -> String {
  case reason {
    process.Normal -> "normal"
    process.Killed -> "killed"
    process.Abnormal(reason) -> string.inspect(reason)
  }
}

fn handle_worker_message(
  state: ExecutionState(ctx),
  message: WorkerMessage,
) -> ExecutionState(ctx) {
  case message {
    HookEvent(_event) -> state

    WorkerCompleted(index, result) -> {
      let indexed = IndexedResult(index: index, result: result)
      ExecutionState(
        ..state,
        running: remove_running_by_index(state.running, index),
        completed: [indexed, ..state.completed],
      )
    }
    WorkerCrashed(pid, reason) -> {
      case find_running_by_pid(state.running, pid) {
        Some(running) -> {
          let failure =
            types.AssertionFailure(
              operator: "crash",
              message: reason,
              payload: None,
            )
          let result =
            TestResult(
              name: last_name(running.full_name),
              full_name: running.full_name,
              status: Failed,
              duration_ms: 0,
              tags: running.tags,
              failures: [failure],
              kind: running.kind,
            )
          let indexed = IndexedResult(index: running.index, result: result)
          ExecutionState(
            ..state,
            running: remove_running_by_pid(state.running, pid),
            completed: [indexed, ..state.completed],
          )
        }
        None -> state
      }
    }
  }
}

fn handle_timeouts(state: ExecutionState(ctx)) -> ExecutionState(ctx) {
  let now = timing.now_ms()
  let #(timed_out, still_running) =
    partition_timeouts(state.running, now, [], [])
  kill_all(timed_out)
  let timeout_results = list.map(timed_out, make_timeout_result)
  ExecutionState(
    ..state,
    running: still_running,
    completed: list.append(timeout_results, state.completed),
  )
}

fn partition_timeouts(
  running: List(RunningTest),
  now: Int,
  timed_out: List(RunningTest),
  still_running: List(RunningTest),
) -> #(List(RunningTest), List(RunningTest)) {
  case running {
    [] -> #(timed_out, still_running)
    [r, ..rest] ->
      case r.deadline_ms <= now {
        True -> partition_timeouts(rest, now, [r, ..timed_out], still_running)
        False -> partition_timeouts(rest, now, timed_out, [r, ..still_running])
      }
  }
}

fn kill_all(running: List(RunningTest)) -> Nil {
  case running {
    [] -> Nil
    [r, ..rest] -> {
      kill(r.worker_pid)
      kill_all(rest)
    }
  }
}

fn make_timeout_result(running: RunningTest) -> IndexedResult {
  IndexedResult(
    index: running.index,
    result: TestResult(
      name: last_name(running.full_name),
      full_name: running.full_name,
      status: TimedOut,
      duration_ms: 0,
      tags: running.tags,
      failures: [],
      kind: running.kind,
    ),
  )
}

fn next_deadline_timeout(running: List(RunningTest), fallback: Int) -> Int {
  case running {
    [] -> fallback
    _ -> fallback
  }
}

fn remove_running_by_index(
  running: List(RunningTest),
  index: Int,
) -> List(RunningTest) {
  list.filter(running, fn(r) { r.index != index })
}

fn remove_running_by_pid(
  running: List(RunningTest),
  pid: Pid,
) -> List(RunningTest) {
  list.filter(running, fn(r) { r.worker_pid != pid })
}

fn find_running_by_pid(
  running: List(RunningTest),
  pid: Pid,
) -> Option(RunningTest) {
  case running {
    [] -> None
    [r, ..rest] ->
      case r.worker_pid == pid {
        True -> Some(r)
        False -> find_running_by_pid(rest, pid)
      }
  }
}

fn sort_results(completed: List(IndexedResult)) -> List(TestResult) {
  completed
  |> list.sort(fn(a, b) { compare_indices(a.index, b.index) })
  |> list.map(fn(r) { r.result })
}

fn compare_indices(a: Int, b: Int) -> order.Order {
  case a < b {
    True -> order.Lt
    False ->
      case a > b {
        True -> order.Gt
        False -> order.Eq
      }
  }
}

fn run_groups_sequentially(
  config: ParallelConfig,
  groups: List(PreparedGroup(ctx)),
  inherited_context: Option(ctx),
  accumulated: List(TestResult),
) -> List(TestResult) {
  case groups {
    [] -> list.reverse(accumulated)
    [group, ..rest] -> {
      let context = case group.initial_context {
        Some(value) -> Some(value)
        None -> inherited_context
      }

      let prepared =
        prepare_suite(
          group.suite,
          context,
          group.name_prefix,
          group.before_each,
          group.after_each,
          group.index_base,
          [],
        )

      let results = run_prepared_tests(config, prepared.tests)
      let nested = run_groups_sequentially(config, prepared.groups, context, [])
      let updated = list.append(list.reverse(results), accumulated)
      let updated2 = list.append(list.reverse(nested), updated)
      run_groups_sequentially(config, rest, inherited_context, updated2)
    }
  }
}

fn run_groups_sequentially_with_reporter(
  config: ParallelConfig,
  groups: List(PreparedGroup(ctx)),
  inherited_context: Option(ctx),
  reporter0: Reporter,
  total: Int,
  completed: Int,
  accumulated_rev: List(TestResult),
) -> #(List(TestResult), Int, Reporter, Option(String)) {
  case groups {
    [] -> #(list.reverse(accumulated_rev), completed, reporter0, None)
    [group, ..rest] -> {
      let context = case group.initial_context {
        Some(value) -> Some(value)
        None -> inherited_context
      }

      let prepared =
        prepare_suite(
          group.suite,
          context,
          group.name_prefix,
          group.before_each,
          group.after_each,
          group.index_base,
          [],
        )

      let #(results, completed1, reporter1) =
        run_prepared_tests_with_reporter(
          config,
          prepared.tests,
          reporter0,
          total,
          completed,
        )

      let #(nested_results, completed2, reporter2, stop_message) =
        run_groups_sequentially_with_reporter(
          config,
          prepared.groups,
          context,
          reporter1,
          total,
          completed1,
          [],
        )

      let scope = list.append(group.name_prefix, [group.suite.name])
      let ctx_value = case context {
        Some(value) -> value
        None -> panic as "missing context for group after_all"
      }

      let #(after_all_results, reporter3) =
        run_after_all_hooks_with_reporter(
          scope,
          ctx_value,
          group.suite.after_all,
          reporter2,
        )

      // Accumulate in traversal order while keeping an efficient accumulator.
      let updated_rev =
        push_results_rev(
          after_all_results,
          push_results_rev(
            nested_results,
            push_results_rev(results, accumulated_rev),
          ),
        )

      // If a nested group already failed its after_all, we must stop here.
      case stop_message {
        Some(message) -> {
          let remaining_results =
            groups_to_setup_failed_results(rest, message, [])
          let #(completed3, reporter4) =
            emit_results_as_test_finished_events(
              remaining_results,
              total,
              completed2,
              reporter3,
            )
          let final_rev = push_results_rev(remaining_results, updated_rev)
          #(list.reverse(final_rev), completed3, reporter4, Some(message))
        }

        None -> {
          case extract_after_all_failure_message(after_all_results) {
            None ->
              run_groups_sequentially_with_reporter(
                config,
                rest,
                inherited_context,
                reporter3,
                total,
                completed2,
                updated_rev,
              )

            Some(message) -> {
              let remaining_results =
                groups_to_setup_failed_results(rest, message, [])
              let #(completed3, reporter4) =
                emit_results_as_test_finished_events(
                  remaining_results,
                  total,
                  completed2,
                  reporter3,
                )
              let final_rev = push_results_rev(remaining_results, updated_rev)
              #(list.reverse(final_rev), completed3, reporter4, Some(message))
            }
          }
        }
      }
    }
  }
}

fn extract_after_all_failure_message(
  results: List(TestResult),
) -> Option(String) {
  case results {
    [] -> None
    [result, ..] ->
      case result.name == "<after_all>" && result.status == Failed {
        True ->
          case result.failures {
            [failure, ..] -> Some(failure.message)
            [] -> Some("after_all failed")
          }
        False -> None
      }
  }
}

fn groups_to_setup_failed_results(
  groups: List(PreparedGroup(ctx)),
  message: String,
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case groups {
    [] -> list.reverse(acc_rev)
    [group, ..rest] -> {
      let group_results = group_to_setup_failed_results(group, message, [])
      let next_acc_rev = push_results_rev(group_results, acc_rev)
      groups_to_setup_failed_results(rest, message, next_acc_rev)
    }
  }
}

fn group_to_setup_failed_results(
  group: PreparedGroup(ctx),
  message: String,
  acc_rev: List(TestResult),
) -> List(TestResult) {
  let pairs = collect_all_tests(group.suite, group.name_prefix, [])
  pairs_to_setup_failed_results(pairs, message, acc_rev)
}

fn pairs_to_setup_failed_results(
  pairs: List(#(List(String), SuiteTestCase(ctx))),
  message: String,
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case pairs {
    [] -> list.reverse(acc_rev)
    [pair, ..rest] -> {
      let #(full_name, test_case) = pair
      let result =
        TestResult(
          name: test_case.name,
          full_name: full_name,
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
      pairs_to_setup_failed_results(rest, message, [result, ..acc_rev])
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
