//// Context-aware unit DSL (`unit_context`).
////
//// Use this module when you want hooks and tests to operate on a shared,
//// strongly-typed context value (your own record/union).
////
//// - You provide an initial context value to `describe`.
//// - `before_all` / `before_each` can transform the context.
//// - `it` receives the current context.
////
//// This builds a `dream_test/types.TestSuite(context)` under the hood.
////
//// ## When should I use this?
////
//// - Use `dream_test/unit` for most tests (no explicit context).
//// - Use `dream_test/unit_context` when you want an explicit context value
////   passed into every test (database handles, fixtures, counters, etc.).
////
//// ## Example
////
//// ```gleam
//// import dream_test/matchers.{be_equal, or_fail_with, should}
//// import dream_test/reporters/bdd
//// import dream_test/reporters/progress
//// import dream_test/runner
//// import dream_test/unit_context.{before_each, describe, it}
////
//// pub type Context {
////   Context(counter: Int)
//// }
////
//// fn increment_counter(context: Context) {
////   Ok(Context(counter: context.counter + 1))
//// }
////
//// pub fn suite() {
////   describe("Context-aware suite", Context(counter: 0), [
////     before_each(increment_counter),
////     it("receives the updated context", fn(context: Context) {
////       context.counter
////       |> should
////       |> be_equal(1)
////       |> or_fail_with("expected counter to be 1 after before_each")
////     }),
////   ])
//// }
////
//// pub fn main() {
////   runner.new([suite()])
////   |> runner.progress_reporter(progress.new())
////   |> runner.results_reporters([bdd.new()])
////   |> runner.exit_on_failure()
////   |> runner.run()
//// }
//// ```

import dream_test/types.{
  type AssertionResult, type Node, type TestSuite, AfterAll, AfterEach,
  AssertionSkipped, BeforeAll, BeforeEach, Group, Root, Test, Unit,
}
import gleam/option.{None}

/// A `Node(context)` built using `dream_test/unit_context`.
pub type ContextNode(context) =
  Node(context)

/// Create a top-level context-aware suite with an explicit initial context.
///
/// ## Parameters
///
/// - `name`: Display name for the suite (shown in reports)
/// - `seed`: Initial context value passed into hooks and tests
/// - `children`: Tests, groups, and hooks that make up the suite
///
/// ## Returns
///
/// A `TestSuite(context)` you can run with `dream_test/runner`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit_context.{before_each, describe, it}
///
/// pub type Context {
///   Context(counter: Int)
/// }
///
/// fn increment_counter(context: Context) {
///   Ok(Context(counter: context.counter + 1))
/// }
///
/// pub fn suite() {
///   describe("Context-aware suite", Context(counter: 0), [
///     before_each(increment_counter),
///     it("receives the updated context", fn(context: Context) {
///       context.counter
///       |> should
///       |> be_equal(1)
///       |> or_fail_with("expected counter to be 1 after before_each")
///     }),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([suite()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
pub fn describe(
  name name: String,
  seed seed: context,
  children children: List(ContextNode(context)),
) -> TestSuite(context) {
  Root(seed: seed, tree: Group(name: name, tags: [], children: children))
}

/// Create a nested group inside a context-aware suite.
///
/// ## Parameters
///
/// - `name`: Display name for the group (shown in reports)
/// - `children`: Tests and hooks that belong to this group
///
/// ## Returns
///
/// A `ContextNode(context)` you can include in `describe`/`group`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit_context.{before_each, describe, group, it}
/// import gleam/io
///
/// pub type Context {
///   Context(counter: Int)
/// }
///
/// fn increment_counter(context: Context) {
///   Ok(Context(counter: context.counter + 1))
/// }
///
/// pub fn suite() {
///   describe("Context-aware grouping", Context(counter: 0), [
///     // This outer hook applies everywhere under this describe, including groups.
///     before_each(increment_counter),
///     group("inner group", [
///       // This hook only applies to tests inside this group.
///       before_each(increment_counter),
///       it("sees both outer + inner hooks", fn(context: Context) {
///         context.counter
///         |> should
///         |> be_equal(2)
///         |> or_fail_with("expected counter to be 2 (outer + inner before_each)")
///       }),
///     ]),
///     it("sees only outer hook", fn(context: Context) {
///       context.counter
///       |> should
///       |> be_equal(1)
///       |> or_fail_with("expected counter to be 1 (outer before_each only)")
///     }),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([suite()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
pub fn group(
  name name: String,
  children children: List(ContextNode(context)),
) -> ContextNode(context) {
  Group(name: name, tags: [], children: children)
}

/// Define a context-aware test case.
///
/// The test body receives the current context and returns:
/// `Result(AssertionResult, String)`.
///
/// ## Parameters
///
/// - `name`: Display name for the test (shown in reports)
/// - `run`: Test body function that receives the current context
///
/// ## Returns
///
/// A `ContextNode(context)` you can include in `describe`/`group`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit_context.{before_each, describe, it}
/// import gleam/io
///
/// pub type Context {
///   Context(counter: Int)
/// }
///
/// fn increment_counter(context: Context) {
///   Ok(Context(counter: context.counter + 1))
/// }
///
/// pub fn suite() {
///   describe("Context-aware suite", Context(counter: 0), [
///     before_each(increment_counter),
///     it("receives the updated context", fn(context: Context) {
///       context.counter
///       |> should
///       |> be_equal(1)
///       |> or_fail_with("expected counter to be 1 after before_each")
///     }),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([suite()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
pub fn it(
  name name: String,
  run run: fn(context) -> Result(AssertionResult, String),
) -> ContextNode(context) {
  Test(
    name: name,
    tags: [],
    kind: Unit,
    run: run,
    timeout_ms: None,
    source: None,
  )
}

/// Define a skipped context-aware test.
///
/// `skip` has the same shape as `it` so you can easily switch a test between
/// running and skipped without rewriting the test body.
///
/// The provided test body is preserved for that purpose, but it is **not
/// executed** while the test is skipped.
///
/// ## Parameters
///
/// - `name`: Display name for the skipped test (shown in reports)
/// - `run`: Unused; kept so you can switch between `it` and `skip` easily
///
/// ## Returns
///
/// A `ContextNode(context)` that always results in `AssertionSkipped`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit_context.{describe, it, skip}
/// import gleam/io
///
/// pub type Context {
///   Context(counter: Int)
/// }
///
/// pub fn suite() {
///   describe("Skipping context-aware tests", Context(counter: 0), [
///     skip("this test is skipped", fn(_context: Context) {
///       // This would pass if it ran, but Dream Test will mark it skipped.
///       Ok(succeed())
///     }),
///     it("normal tests still run", fn(context: Context) {
///       context.counter
///       |> should
///       |> be_equal(0)
///       |> or_fail_with("expected counter to start at 0")
///     }),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([suite()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
pub fn skip(
  name name: String,
  run _run: fn(context) -> Result(AssertionResult, String),
) -> ContextNode(context) {
  Test(
    name: name,
    tags: [],
    kind: Unit,
    run: skipped_test_run,
    timeout_ms: None,
    source: None,
  )
}

/// Run once before any tests and produce/transform the context.
pub fn before_all(
  setup setup: fn(context) -> Result(context, String),
) -> ContextNode(context) {
  BeforeAll(setup)
}

/// Run before each test and transform the context for that test.
pub fn before_each(
  setup setup: fn(context) -> Result(context, String),
) -> ContextNode(context) {
  BeforeEach(setup)
}

/// Run after each test for cleanup.
pub fn after_each(
  teardown teardown: fn(context) -> Result(Nil, String),
) -> ContextNode(context) {
  AfterEach(teardown)
}

/// Run once after all tests for cleanup.
pub fn after_all(
  teardown teardown: fn(context) -> Result(Nil, String),
) -> ContextNode(context) {
  AfterAll(teardown)
}

/// Attach tags to a node.
///
/// Tags can be used by runners and reporters for filtering and display.
/// Prefer piping: `node |> with_tags(["tag"])`.
///
/// ## Parameters
///
/// - `node`: A group or test node to tag
/// - `tags`: Tags to attach (replaces any existing tags on that node)
///
/// ## Returns
///
/// A new node with the provided tags.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{succeed}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit_context.{describe, group, it, with_tags}
/// import gleam/io
///
/// pub type Context {
///   Context(counter: Int)
/// }
///
/// pub fn suite() {
///   describe("Tagging context-aware tests", Context(counter: 0), [
///     group("group tagged slow", [
///       it("inherits the group tag", fn(_context: Context) { Ok(succeed()) }),
///     ])
///       |> with_tags(["slow"]),
///     it("can tag an individual test", fn(_context: Context) { Ok(succeed()) })
///       |> with_tags(["unit_context", "fast"]),
///     it("untagged tests still work", fn(_context: Context) { Ok(succeed()) }),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([suite()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
pub fn with_tags(
  node node: ContextNode(context),
  tags tags: List(String),
) -> ContextNode(context) {
  case node {
    Group(name, _, children) ->
      Group(name: name, tags: tags, children: children)
    Test(name, _, kind, run, timeout_ms, source) ->
      Test(
        name: name,
        tags: tags,
        kind: kind,
        run: run,
        timeout_ms: timeout_ms,
        source: source,
      )
    other -> other
  }
}

fn skipped_test_run(_context: a) -> Result(AssertionResult, String) {
  Ok(AssertionSkipped)
}
