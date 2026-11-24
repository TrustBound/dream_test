//// Context-aware unit DSL (`unit_context`).
////
//// Use this module when you want hooks and tests to operate on a shared,
//// strongly-typed context value (your own record/union).
////
//// - You give `describe` a `dream_test/context.Context`: a fixed value
////   (`context.value`) or a value from a setup (`context.setup`).
//// - `before_all` / `before_each` can transform the context.
//// - `it` receives the current context.
////
//// This builds a `dream_test/suite.TestSuite` under the hood. The context
//// stays inside the suite, so a context suite runs with other suites in
//// one `runner.new`.
////
//// ## When should I use this?
////
//// - Use `dream_test/unit` for most tests (no explicit context).
//// - Use `dream_test/unit_context` when you want an explicit context value
////   passed into every test (database handles, fixtures, counters, etc.).
////
//// ## Example
////
//// ### Write a context suite and run it <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/unit_context/describe.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_test/context
//// import dream_test/matchers.{be_equal, or_fail_with, should}
//// import dream_test/reporters/bdd
//// import dream_test/reporters/progress
//// import dream_test/runner
//// import dream_test/suite.{type TestSuite}
//// import dream_test/types.{type RunReport}
//// import dream_test/unit_context.{before_each, describe, it}
////
//// pub type Context {
////   Context(counter: Int)
//// }
////
//// fn increment_counter(context: Context) -> Result(Context, String) {
////   Ok(Context(counter: context.counter + 1))
//// }
////
//// pub fn suite() -> TestSuite {
////   describe("Context-aware suite", context.value(Context(counter: 0)), [
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
//// pub fn main() -> RunReport {
////   runner.new([suite()])
////   |> runner.progress_reporter(progress.new())
////   |> runner.results_reporters([bdd.new()])
////   |> runner.exit_on_failure()
////   |> runner.run()
//// }
//// ```

import dream_test/context.{type Context}
import dream_test/suite.{type TestSuite}
import dream_test/types.{
  type AssertionResult, type Node, AfterAll, AfterEach, AssertionPending,
  AssertionSkipped, BeforeAll, BeforeEach, Group, NoInput, Test, Unit, WithInput,
}
import gleam/option.{None}

/// A `Node(context)` built using `dream_test/unit_context`.
pub type ContextNode(context) =
  Node(context)

/// Create a top-level context-aware suite.
///
/// The `context` says where the hooks and tests get their context:
///
/// - `context.value(start)`: each test starts from the fixed value `start`.
/// - `context.setup(start, teardown)`: `start` makes the value once, before
///   the first test of the suite, and `teardown` gets the value after the
///   last test (see `context.setup`).
///
/// ## Parameters
///
/// - `name`: Display name for the suite (shown in reports)
/// - `context`: where the hooks and tests get their context (see
///   `dream_test/context`)
/// - `tests`: Tests, groups, and hooks that make up the suite
///
/// ## Returns
///
/// A `TestSuite` you can run with `dream_test/runner`, also in one run with
/// suites of other context types.
///
/// ## Example
///
/// ### Write a context suite and run it <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/unit_context/describe.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/suite.{type TestSuite}
/// import dream_test/types.{type RunReport}
/// import dream_test/unit_context.{before_each, describe, it}
///
/// pub type Context {
///   Context(counter: Int)
/// }
///
/// fn increment_counter(context: Context) -> Result(Context, String) {
///   Ok(Context(counter: context.counter + 1))
/// }
///
/// pub fn suite() -> TestSuite {
///   describe("Context-aware suite", context.value(Context(counter: 0)), [
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
/// pub fn main() -> RunReport {
///   runner.new([suite()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
pub fn describe(
  name name: String,
  context start: Context(context),
  tests tests: List(ContextNode(context)),
) -> TestSuite {
  suite.new(
    name: name,
    tags: [],
    tests: tests,
    context: context.to_suite_context(start),
  )
}

/// Create a nested group inside a context-aware suite.
///
/// ## Parameters
///
/// - `name`: Display name for the group (shown in reports)
/// - `tests`: Tests and hooks that belong to this group
///
/// ## Returns
///
/// A `ContextNode(context)` you can include in `describe`/`group`.
///
/// ## Example
///
/// ### Group tests that share a context <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/unit_context/group.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/suite.{type TestSuite}
/// import dream_test/types.{type RunReport}
/// import dream_test/unit_context.{before_each, describe, group, it}
///
/// pub type Context {
///   Context(counter: Int)
/// }
///
/// fn increment_counter(context: Context) -> Result(Context, String) {
///   Ok(Context(counter: context.counter + 1))
/// }
///
/// pub fn suite() -> TestSuite {
///   describe("Context-aware grouping", context.value(Context(counter: 0)), [
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
/// pub fn main() -> RunReport {
///   runner.new([suite()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
pub fn group(
  name name: String,
  tests tests: List(ContextNode(context)),
) -> ContextNode(context) {
  Group(name: name, tags: [], children: tests)
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
/// ### Write a test that gets the context <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/unit_context/describe.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/suite.{type TestSuite}
/// import dream_test/types.{type RunReport}
/// import dream_test/unit_context.{before_each, describe, it}
///
/// pub type Context {
///   Context(counter: Int)
/// }
///
/// fn increment_counter(context: Context) -> Result(Context, String) {
///   Ok(Context(counter: context.counter + 1))
/// }
///
/// pub fn suite() -> TestSuite {
///   describe("Context-aware suite", context.value(Context(counter: 0)), [
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
/// pub fn main() -> RunReport {
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
    run: WithInput(run),
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
/// ### Skip a context test <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/unit_context/skip.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/suite.{type TestSuite}
/// import dream_test/types.{type RunReport}
/// import dream_test/unit_context.{describe, it, skip}
///
/// pub type Context {
///   Context(counter: Int)
/// }
///
/// pub fn suite() -> TestSuite {
///   describe("Skipping context-aware tests", context.value(Context(counter: 0)), [
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
/// pub fn main() -> RunReport {
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
    run: WithInput(skipped_test_run),
    timeout_ms: None,
    source: None,
  )
}

/// Run once before any tests and produce/transform the context.
///
/// It runs in the setup process of the group, so a resource that it starts
/// lives for all the tests of the group. It gets the default timeout. If it
/// returns `Error`, times out or crashes, all tests under this group become
/// `SetupFailed`. It does not run for a group that has no test after
/// filtering.
///
/// ## Example
///
/// ### Load the context once for all tests <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/unit_context/before_all.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/suite.{type TestSuite}
/// import dream_test/unit_context.{before_all, describe, it}
///
/// pub fn suite() -> TestSuite {
///   describe("Price list", context.value([]), [
///     before_all(fn(_prices) { Ok([10, 20, 30]) }),
///     it("has three prices", fn(prices: List(Int)) {
///       prices
///       |> should
///       |> be_equal([10, 20, 30])
///       |> or_fail_with("expected the prices that before_all loaded")
///     }),
///   ])
/// }
/// ```
pub fn before_all(
  setup setup: fn(context) -> Result(context, String),
) -> ContextNode(context) {
  BeforeAll(WithInput(setup))
}

/// Run before each test and transform the context for that test.
///
/// ## Example
///
/// ### Give each test a new context <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/unit_context/before_each.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/suite.{type TestSuite}
/// import dream_test/unit_context.{before_each, describe, it}
///
/// pub fn suite() -> TestSuite {
///   describe("Counter", context.value(0), [
///     before_each(fn(count) { Ok(count + 1) }),
///     it("starts at one", fn(count: Int) {
///       count
///       |> should
///       |> be_equal(1)
///       |> or_fail_with("expected before_each to add one")
///     }),
///     it("starts at one again", fn(count: Int) {
///       count
///       |> should
///       |> be_equal(1)
///       |> or_fail_with("expected a new count for each test")
///     }),
///   ])
/// }
/// ```
pub fn before_each(
  setup setup: fn(context) -> Result(context, String),
) -> ContextNode(context) {
  BeforeEach(WithInput(setup))
}

/// Run after each test for cleanup.
///
/// If it returns `Error` or crashes, the status of the test does not change:
/// the run report gets a `types.TeardownFailed`, and the run fails. If the
/// body times out or the test process stops, it still runs, in a new
/// process, with the context after the last `before_each` hook that
/// returned.
///
/// ## Example
///
/// ### Clean up after each test <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/unit_context/after_each.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{succeed}
/// import dream_test/runner
/// import dream_test/types.{type RunReport}
/// import dream_test/unit_context.{after_each, describe, it}
/// import gleam/io
///
/// pub fn main() -> RunReport {
///   runner.new([
///     describe("Session", context.value("session-1"), [
///       after_each(close_session),
///       it("is open", fn(_session: String) { Ok(succeed()) }),
///     ]),
///   ])
///   |> runner.run()
/// }
///
/// fn close_session(session: String) -> Result(Nil, String) {
///   io.println("closing " <> session)
///   Ok(Nil)
/// }
/// ```
pub fn after_each(
  teardown teardown: fn(context) -> Result(Nil, String),
) -> ContextNode(context) {
  AfterEach(WithInput(teardown))
}

/// Run once after all tests for cleanup.
///
/// It runs in the setup process of the group, with the default timeout.
/// Every `after_all` hook
/// runs, also after one fails. A failure goes into the hook failures of
/// the run report, and the run fails. It does not run for a group that has
/// no test after filtering.
///
/// ## Example
///
/// ### Clean up once after all tests <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/unit_context/after_all.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{succeed}
/// import dream_test/runner
/// import dream_test/types.{type RunReport}
/// import dream_test/unit_context.{after_all, describe, it}
/// import gleam/io
///
/// pub fn main() -> RunReport {
///   runner.new([
///     describe("Pool", context.value("pool-1"), [
///       after_all(stop_pool),
///       it("lends a connection", fn(_pool: String) { Ok(succeed()) }),
///       it("takes it back", fn(_pool: String) { Ok(succeed()) }),
///     ]),
///   ])
///   |> runner.run()
/// }
///
/// fn stop_pool(pool: String) -> Result(Nil, String) {
///   io.println("stopping " <> pool)
///   Ok(Nil)
/// }
/// ```
pub fn after_all(
  teardown teardown: fn(context) -> Result(Nil, String),
) -> ContextNode(context) {
  AfterAll(WithInput(teardown))
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
/// ### Tag context tests and groups <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/unit_context/with_tags.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{succeed}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/suite.{type TestSuite}
/// import dream_test/types.{type RunReport}
/// import dream_test/unit_context.{describe, group, it, with_tags}
///
/// pub type Context {
///   Context(counter: Int)
/// }
///
/// pub fn suite() -> TestSuite {
///   describe("Tagging context-aware tests", context.value(Context(counter: 0)), [
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
/// pub fn main() -> RunReport {
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

/// Define a pending test: a test with a name and no body yet.
///
/// Use it to write the skeleton of a suite first and fill in the tests
/// later. A pending test has the status `Pending`. The reporters show it
/// with `~` and count it as pending, and the run still passes, as with a
/// skipped test.
///
/// ## Parameters
///
/// - `name`: the test name
///
/// ## Returns
///
/// A test whose status is `Pending` (`AssertionPending`).
///
/// ## Example
///
/// ### Add pending tests to a context suite <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/unit_context/pending.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{succeed}
/// import dream_test/suite.{type TestSuite}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit_context.{describe, it, pending}
///
/// fn adds_an_item(_items: List(String)) -> Result(AssertionResult, String) {
///   Ok(succeed())
/// }
///
/// pub fn cart_suite() -> TestSuite {
///   describe("Cart", context.value([]), [
///     it("adds an item", adds_an_item),
///     pending("removes an item"),
///     pending("empties the cart"),
///   ])
/// }
/// ```
pub fn pending(name name: String) -> ContextNode(context) {
  Test(
    name: name,
    tags: [],
    kind: Unit,
    run: NoInput(pending_test_run),
    timeout_ms: None,
    source: None,
  )
}

fn pending_test_run() -> Result(AssertionResult, String) {
  Ok(AssertionPending)
}
