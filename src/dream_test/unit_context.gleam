//// Context-aware unit DSL (`unit_context`).
////
//// Use this module when you want hooks and tests to operate on a shared,
//// strongly-typed context value (your own record/union).
////
//// - You provide an initial context value to `describe`.
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

import dream_test/suite.{type TestSuite}
import dream_test/types.{
  type AssertionResult, type Node, AfterAll, AfterEach, AssertionPending,
  AssertionSkipped, BeforeAll, BeforeEach, ContextFromSetup, Group, NoInput,
  Test, Tree, Unit, WithInput,
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
/// A `TestSuite` you can run with `dream_test/runner`, also in one run with
/// suites of other context types.
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
) -> TestSuite {
  suite.from_tree(Tree(seed: seed, name: name, tags: [], children: children))
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
pub fn before_all(
  setup setup: fn(context) -> Result(context, String),
) -> ContextNode(context) {
  BeforeAll(WithInput(setup))
}

/// Run before each test and transform the context for that test.
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

/// Create a suite whose context comes from a setup.
///
/// `setup` runs once for the tests of this `describe_with_setup`, before
/// the first of them, and only when at least one of them runs. A
/// `suite.join` or `suite.group` of two such suites runs two setups. Its value is the context of every
/// hook and test. `teardown` gets the same value after the last test. The
/// setup and the teardown run in one process that lives while the tests
/// run, so a process that the setup starts and links stays alive.
///
/// - When `setup` returns `Error`, crashes or times out, each test is
///   `SetupFailed` with the operator `context setup`, and `teardown` does not run.
/// - When the process of the setup stops, the tests that did not start
///   are `SetupFailed`, and the run report gets a `types.SetupStopped` with
///   the setup `types.ContextSetupHook`. `teardown` still runs when the
///   setup returned.
/// - When `teardown` returns `Error`, crashes or times out, the run report
///   gets a `types.TeardownFailed` with the hook `types.ContextTeardownHook`.
///
/// ## Parameters
///
/// - `name`: the suite name (shown in reports)
/// - `setup`: gives the context, or `Error` with a message
/// - `teardown`: gets the context after the last test
/// - `children`: tests, groups and hooks that get the context
///
/// ## Returns
///
/// A `TestSuite` you can run with other suites in one `runner.new`.
///
/// ## Example
///
/// ```gleam
/// describe_with_setup(
///   "Server",
///   setup: start_server,
///   teardown: stop_server,
///   children: [it("answers a ping", answers_a_ping)],
/// )
/// ```
pub fn describe_with_setup(
  name name: String,
  setup setup: fn() -> Result(context, String),
  teardown teardown: fn(context) -> Result(Nil, String),
  children children: List(ContextNode(context)),
) -> TestSuite {
  suite.new(
    name: name,
    tags: [],
    children: children,
    context: ContextFromSetup(setup: setup, teardown: teardown),
  )
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
/// ```gleam
/// describe("Cart", [
///   it("adds an item", adds_an_item),
///   pending("removes an item"),
///   pending("empties the cart"),
/// ])
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
