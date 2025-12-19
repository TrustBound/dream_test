//// Unit test DSL (no explicit context).
////
//// This is the default DSL for most users: `describe` + `it` with **0‑argument**
//// test bodies.
////
//// - Tests are written as `it("does something", fn() { ... })`
//// - Hooks are also **0‑argument** functions (`before_each(fn() { ... })`)
//// - All hooks/tests return `Result(AssertionResult, String)` so you can abort
////   early with `Error("message")` when prerequisites fail.
////
//// This module builds a `dream_test/types.TestSuite(Nil)` under the hood.
////
//// ## When should I use this module?
////
//// - Use `dream_test/unit` for most unit tests.
//// - Use `dream_test/unit_context` only when you want a **real context value**
////   threaded through hooks and test bodies.
////
//// ## Example (from snippets)
////
//// ```gleam
//// // examples/snippets/test/snippets/unit/quick_start.gleam
//// import dream_test/assertions/should.{equal, or_fail_with, should}
//// import dream_test/unit.{describe, it}
//// import gleam/string
////
//// pub fn tests() {
////   describe("String utilities", [
////     it("trims whitespace", fn() {
////       "  hello  "
////       |> string.trim()
////       |> should
////       |> equal("hello")
////       |> or_fail_with("Should remove surrounding whitespace")
////     }),
////   ])
//// }
//// ```

import dream_test/types.{
  type AssertionResult, type Node, type TestSuite, AfterAll, AfterEach,
  AssertionSkipped, BeforeAll, BeforeEach, Group, Root, Test, Unit,
}
import gleam/option.{None}

/// A `Node(Nil)` built using the `dream_test/unit` DSL.
///
/// You generally don’t need to construct nodes directly; use `group`, `it`,
/// and the hook helpers in this module.
pub type UnitNode =
  Node(Nil)

/// Create a top-level test suite.
///
/// The returned value is what you pass to `runner.new([ ... ])`.
///
/// ## Example
///
/// See `examples/snippets/test/snippets/unit/quick_start.gleam`.
pub fn describe(name: String, children: List(UnitNode)) -> TestSuite(Nil) {
  Root(seed: Nil, tree: Group(name: name, tags: [], children: children))
}

/// Create a nested group inside a suite.
///
/// Groups provide structure (and hook scoping). Hooks declared in an outer group
/// apply to tests in inner groups.
///
/// ## Example
///
/// See `examples/snippets/test/snippets/hooks/hook_inheritance.gleam`.
pub fn group(name: String, children: List(UnitNode)) -> UnitNode {
  Group(name: name, tags: [], children: children)
}

/// Define a single test case.
///
/// - The body is **0-arg** (`fn() { ... }`)
/// - Return `Ok(...)` to indicate an assertion result
/// - Return `Error("message")` to abort the test with a message
///
/// ## Example
///
/// See `examples/snippets/test/snippets/unit/quick_start.gleam`.
pub fn it(
  name: String,
  run: fn() -> Result(AssertionResult, String),
) -> UnitNode {
  Test(
    name: name,
    tags: [],
    kind: Unit,
    run: fn(_nil: Nil) { run() },
    timeout_ms: None,
  )
}

/// Define a skipped test.
///
/// The function is accepted for ergonomics, but it is **not executed**.
///
/// ## Example
///
/// See `examples/snippets/test/snippets/unit/skipping_tests.gleam`.
pub fn skip(
  name: String,
  _run: fn() -> Result(AssertionResult, String),
) -> UnitNode {
  Test(
    name: name,
    tags: [],
    kind: Unit,
    run: fn(_nil: Nil) { Ok(AssertionSkipped) },
    timeout_ms: None,
  )
}

/// Run once before any tests in the current suite/group.
///
/// - Runs in a sandboxed process.
/// - If it returns `Error("message")`, all tests under this scope become
///   `SetupFailed`.
///
/// ## Example
///
/// See `examples/snippets/test/snippets/hooks/lifecycle_hooks.gleam`.
pub fn before_all(setup: fn() -> Result(Nil, String)) -> UnitNode {
  BeforeAll(fn(_nil: Nil) {
    case setup() {
      Ok(_) -> Ok(Nil)
      Error(message) -> Error(message)
    }
  })
}

/// Run before each test in the current scope.
///
/// - Runs in a sandboxed process.
/// - If it returns `Error("message")`, that test becomes `SetupFailed` and the
///   body does not run.
///
/// ## Example
///
/// See `examples/snippets/test/snippets/hooks/lifecycle_hooks.gleam`.
pub fn before_each(setup: fn() -> Result(Nil, String)) -> UnitNode {
  BeforeEach(fn(_nil: Nil) {
    case setup() {
      Ok(_) -> Ok(Nil)
      Error(message) -> Error(message)
    }
  })
}

/// Run after each test in the current scope.
///
/// This is useful for cleanup that must always run (even after assertion
/// failures).
///
/// ## Example
///
/// See `examples/snippets/test/snippets/hooks/lifecycle_hooks.gleam`.
pub fn after_each(teardown: fn() -> Result(Nil, String)) -> UnitNode {
  AfterEach(fn(_nil: Nil) { teardown() })
}

/// Run once after all tests in the current scope.
///
/// ## Example
///
/// See `examples/snippets/test/snippets/hooks/lifecycle_hooks.gleam`.
pub fn after_all(teardown: fn() -> Result(Nil, String)) -> UnitNode {
  AfterAll(fn(_nil: Nil) { teardown() })
}

/// Attach tags to a node.
///
/// Tags propagate to descendant tests and are included in `TestResult.tags`.
/// Use tags to filter results (e.g. in CI) with `runner.filter_results`.
///
/// ## Example
///
/// See `examples/snippets/test/snippets/gherkin/gherkin_feature.gleam` for scenario tags (Gherkin),
/// and see `test/dream_test/unit_api_test.gleam` for unit tag propagation.
pub fn with_tags(node: UnitNode, tags: List(String)) -> UnitNode {
  case node {
    Group(name, _, children) ->
      Group(name: name, tags: tags, children: children)
    Test(name, _, kind, run, timeout_ms) ->
      Test(name: name, tags: tags, kind: kind, run: run, timeout_ms: timeout_ms)
    other -> other
  }
}
