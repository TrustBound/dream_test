//// Context-aware unit DSL (`unit_context`).
////
//// Use this module when you want hooks and tests to operate on a shared,
//// strongly-typed **context value** (your own record/union).
////
//// - You provide an initial `seed` value to `describe`.
//// - `before_all` / `before_each` can transform the context.
//// - `it` receives the current context.
////
//// This builds a `dream_test/types.TestSuite(context)` under the hood.
////
//// ## When should I use this?
////
//// - Use `dream_test/unit` for most tests (no explicit context).
//// - Use `dream_test/unit_context` when you want an explicit context (e.g. a
////   test DB handle, a prebuilt fixture, counters, accumulated state).
////
//// ## Example (from snippets)
////
//// ```gleam
//// // examples/snippets/test/snippets/hooks/context_aware_tests.gleam
//// import dream_test/assertions/should.{equal, or_fail_with, should}
//// import dream_test/unit_context.{before_each, describe, it}
////
//// pub type Ctx { Ctx(counter: Int) }
////
//// fn increment(ctx: Ctx) { Ok(Ctx(counter: ctx.counter + 1)) }
////
//// fn counter_is_one(ctx: Ctx) {
////   ctx.counter
////   |> should
////   |> equal(1)
////   |> or_fail_with("expected counter to be 1 after before_each")
//// }
////
//// pub fn suite() {
////   describe("Context-aware suite", Ctx(counter: 0), [
////     before_each(increment),
////     it("receives the updated context", counter_is_one),
////   ])
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
pub fn describe(
  name: String,
  seed: context,
  children: List(ContextNode(context)),
) -> TestSuite(context) {
  Root(seed: seed, tree: Group(name: name, tags: [], children: children))
}

/// Create a nested group inside a context-aware suite.
pub fn group(
  name: String,
  children: List(ContextNode(context)),
) -> ContextNode(context) {
  Group(name: name, tags: [], children: children)
}

/// Define a context-aware test case.
///
/// The test body receives the current context and returns:
/// `Result(AssertionResult, String)`.
pub fn it(
  name: String,
  run: fn(context) -> Result(AssertionResult, String),
) -> ContextNode(context) {
  Test(name: name, tags: [], kind: Unit, run: run, timeout_ms: None)
}

/// Define a skipped context-aware test.
pub fn skip(
  name: String,
  _run: fn(context) -> Result(AssertionResult, String),
) -> ContextNode(context) {
  Test(
    name: name,
    tags: [],
    kind: Unit,
    run: fn(_ctx: context) { Ok(AssertionSkipped) },
    timeout_ms: None,
  )
}

/// Run once before any tests and produce/transform the context.
pub fn before_all(
  setup: fn(context) -> Result(context, String),
) -> ContextNode(context) {
  BeforeAll(setup)
}

/// Run before each test and transform the context for that test.
pub fn before_each(
  setup: fn(context) -> Result(context, String),
) -> ContextNode(context) {
  BeforeEach(setup)
}

/// Run after each test for cleanup.
pub fn after_each(
  teardown: fn(context) -> Result(Nil, String),
) -> ContextNode(context) {
  AfterEach(teardown)
}

/// Run once after all tests for cleanup.
pub fn after_all(
  teardown: fn(context) -> Result(Nil, String),
) -> ContextNode(context) {
  AfterAll(teardown)
}

/// Attach tags to a node.
pub fn with_tags(
  node: ContextNode(context),
  tags: List(String),
) -> ContextNode(context) {
  case node {
    Group(name, _, children) ->
      Group(name: name, tags: tags, children: children)
    Test(name, _, kind, run, timeout_ms) ->
      Test(name: name, tags: tags, kind: kind, run: run, timeout_ms: timeout_ms)
    other -> other
  }
}
