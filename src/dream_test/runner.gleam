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
//// ## Example (from snippets)
////
//// ```gleam
//// // examples/snippets/test/snippets/unit/quick_start.gleam
//// import dream_test/reporters
//// import dream_test/runner
//// import dream_test/unit.{describe, it}
//// import gleam/io
////
//// pub fn main() {
////   let suite = describe("Example", [it("passes", fn() { Ok(succeed()) })])
////   runner.new([suite])
////   |> runner.reporter(reporters.bdd(io.print, True))
////   |> runner.exit_on_failure()
////   |> runner.run()
//// }
//// ```

import dream_test/parallel
import dream_test/reporters
import dream_test/reporters/types as reporter_types
import dream_test/types.{
  type Node, type TestKind, type TestResult, type TestSuite, AfterAll, AfterEach,
  BeforeAll, BeforeEach, Failed, Group, Root, SetupFailed, Test, TimedOut,
}
import gleam/list
import gleam/option.{type Option, None, Some}

/// Lightweight information about a test, used for filtering what runs.
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
/// configuration helpers like `runner.reporter`, `runner.max_concurrency`, etc.
pub opaque type RunBuilder(ctx) {
  RunBuilder(
    suites: List(TestSuite(ctx)),
    config: parallel.ParallelConfig,
    test_filter: Option(fn(TestInfo) -> Bool),
    should_exit_on_failure: Bool,
    reporter: Option(reporters.Reporter),
  )
}

/// Create a new runner builder for a list of suites.
///
/// The type parameter `ctx` is the suite context type. For `dream_test/unit`
/// suites this is `Nil`. For `dream_test/unit_context` suites it is your custom
/// context type.
pub fn new(suites: List(TestSuite(ctx))) -> RunBuilder(ctx) {
  RunBuilder(
    suites: suites,
    config: parallel.default_config(),
    test_filter: None,
    should_exit_on_failure: False,
    reporter: None,
  )
}

/// Set the maximum number of concurrently running tests.
///
/// - `1` gives fully sequential test execution.
/// - Higher values increase parallelism.
///
/// ## Example (from snippets)
///
/// See `examples/snippets/test/snippets/runner/sequential_execution.gleam`.
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

/// Set the default timeout (milliseconds) applied to tests without an explicit timeout.
///
/// Tests that exceed the timeout are killed and reported as `TimedOut`.
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

/// Exit the BEAM with a non-zero code if any tests fail.
///
/// Useful for CI pipelines.
pub fn exit_on_failure(builder: RunBuilder(ctx)) -> RunBuilder(ctx) {
  RunBuilder(..builder, should_exit_on_failure: True)
}

/// Attach an event-driven reporter.
///
/// Use `dream_test/reporters` to construct a reporter (BDD/JSON/Progress).
pub fn reporter(
  builder: RunBuilder(ctx),
  reporter: reporters.Reporter,
) -> RunBuilder(ctx) {
  RunBuilder(..builder, reporter: Some(reporter))
}

/// Filter which tests are executed.
///
/// The predicate receives `TestInfo` (name, full name, effective tags, kind).
/// Tags include inherited group tags.
///
/// Groups with no selected tests in their entire subtree are skipped entirely,
/// including hooks.
pub fn filter_tests(
  builder: RunBuilder(ctx),
  predicate: fn(TestInfo) -> Bool,
) -> RunBuilder(ctx) {
  RunBuilder(..builder, test_filter: Some(predicate))
}

/// Run all suites and return a list of `TestResult`.
///
/// If a reporter is attached, the runner will emit `ReporterEvent`s during the run.
pub fn run(builder: RunBuilder(ctx)) -> List(TestResult) {
  let selected_suites = apply_test_filter(builder.suites, builder.test_filter)
  let total = count_total_tests(selected_suites)

  let #(results, _completed, _final_reporter) = case builder.reporter {
    None -> #(
      run_without_reporter(RunBuilder(..builder, suites: selected_suites)),
      total,
      None,
    )
    Some(reporter0) -> {
      let reporter1 =
        reporters.handle_event(reporter0, reporter_types.RunStarted(total))

      let #(results, completed, reporter2) =
        run_with_reporter(
          selected_suites,
          builder.config,
          reporter1,
          total,
          0,
          [],
        )

      let reporter3 =
        reporters.handle_event(
          reporter2,
          reporter_types.RunFinished(completed, total),
        )

      #(results, completed, Some(reporter3))
    }
  }

  case builder.should_exit_on_failure {
    True ->
      case has_failures(results) {
        True -> halt(1)
        False -> Nil
      }
    False -> Nil
  }

  results
}

fn run_without_reporter(builder: RunBuilder(ctx)) -> List(TestResult) {
  run_suites_no_reporter(builder.suites, builder.config, [])
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

fn run_suites_no_reporter(
  suites: List(TestSuite(ctx)),
  config: parallel.ParallelConfig,
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case suites {
    [] -> list.reverse(acc_rev)
    [suite, ..rest] ->
      run_suites_no_reporter(
        rest,
        config,
        list.append(parallel.run_root_parallel(config, suite), acc_rev),
      )
  }
}

fn run_with_reporter(
  suites: List(TestSuite(ctx)),
  config: parallel.ParallelConfig,
  reporter0: reporters.Reporter,
  total: Int,
  completed: Int,
  acc_rev: List(TestResult),
) -> #(List(TestResult), Int, reporters.Reporter) {
  case suites {
    [] -> #(list.reverse(acc_rev), completed, reporter0)
    [suite, ..rest] -> {
      let #(results, completed1, reporter1) =
        parallel.run_root_parallel_with_reporter(
          config,
          suite,
          reporter0,
          total,
          completed,
        )

      run_with_reporter(
        rest,
        config,
        reporter1,
        total,
        completed1,
        list.append(results, acc_rev),
      )
    }
  }
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
pub fn has_failures(results: List(TestResult)) -> Bool {
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
