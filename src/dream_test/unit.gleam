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
//// ## Example
////
//// ```gleam
//// import dream_test/matchers.{be_equal, or_fail_with, should}
//// import dream_test/reporters/bdd
//// import dream_test/reporters/progress
//// import dream_test/runner
//// import dream_test/unit.{describe, it}
//// import gleam/string
////
//// pub fn tests() {
////   describe("String utilities", [
////     it("trims whitespace", fn() {
////       "  hello  "
////       |> string.trim()
////       |> should
////       |> be_equal("hello")
////       |> or_fail_with("Should remove surrounding whitespace")
////     }),
////     it("finds substrings", fn() {
////       "hello world"
////       |> string.contains("world")
////       |> should
////       |> be_equal(True)
////       |> or_fail_with("Should find 'world' in string")
////     }),
////   ])
//// }
////
//// pub fn main() {
////   runner.new([tests()])
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

/// A `Node(Nil)` built using the `dream_test/unit` DSL.
///
/// You generally don’t need to construct nodes directly; use `group`, `it`,
/// and the hook helpers in this module.
///
/// ## Parameters
///
/// `UnitNode` is an alias of `types.Node(Nil)`, where the context type is `Nil`.
/// This module creates these nodes for you.
pub type UnitNode =
  Node(Nil)

/// Create a top-level test suite.
///
/// The returned value is what you pass to `runner.new([ ... ])`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit.{describe, it}
/// import gleam/string
///
/// pub fn tests() {
///   describe("String utilities", [
///     it("trims whitespace", fn() {
///       "  hello  "
///       |> string.trim()
///       |> should
///       |> be_equal("hello")
///       |> or_fail_with("Should remove surrounding whitespace")
///     }),
///     it("finds substrings", fn() {
///       "hello world"
///       |> string.contains("world")
///       |> should
///       |> be_equal(True)
///       |> or_fail_with("Should find 'world' in string")
///     }),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// ## Parameters
///
/// - `name`: the suite name (shown in reports)
/// - `children`: the suite contents (tests, groups, and hooks)
///
/// ## Returns
///
/// A `TestSuite(Nil)` you can pass to `runner.new([ ... ])`.
pub fn describe(
  name name: String,
  children children: List(UnitNode),
) -> TestSuite(Nil) {
  Root(seed: Nil, tree: Group(name: name, tags: [], children: children))
}

/// Create a nested group inside a suite.
///
/// Groups provide structure (and hook scoping). Hooks declared in an outer group
/// apply to tests in inner groups.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit.{describe, group, it}
/// import gleam/io
///
/// pub fn tests() {
///   describe("Calculator", [
///     group("addition", [
///       it("adds small numbers", fn() {
///         2 + 3
///         |> should
///         |> be_equal(5)
///         |> or_fail_with("2 + 3 should equal 5")
///       }),
///       it("adds negative numbers", fn() {
///         -2 + -3
///         |> should
///         |> be_equal(-5)
///         |> or_fail_with("-2 + -3 should equal -5")
///       }),
///     ]),
///     group("division", [
///       it("integer division rounds toward zero", fn() {
///         7 / 2
///         |> should
///         |> be_equal(3)
///         |> or_fail_with("7 / 2 should equal 3")
///       }),
///     ]),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// ## Parameters
///
/// - `name`: the group name (shown in reports and in `runner.TestInfo.full_name`)
/// - `children`: nested tests/groups/hooks under this group
///
/// ## Returns
///
/// A `UnitNode` you include in a parent `describe`/`group` children list.
pub fn group(name name: String, children children: List(UnitNode)) -> UnitNode {
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
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit.{describe, it}
/// import gleam/io
/// import gleam/string
///
/// pub fn tests() {
///   describe("String utilities", [
///     it("trims whitespace", fn() {
///       "  hello  "
///       |> string.trim()
///       |> should
///       |> be_equal("hello")
///       |> or_fail_with("Should remove surrounding whitespace")
///     }),
///     it("finds substrings", fn() {
///       "hello world"
///       |> string.contains("world")
///       |> should
///       |> be_equal(True)
///       |> or_fail_with("Should find 'world' in string")
///     }),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// ## Parameters
///
/// - `name`: the test name (shown in reports)
/// - `run`: a **0-argument** test body that returns `Result(AssertionResult, String)`
///
/// ## Returns
///
/// A `UnitNode` representing the test.
pub fn it(
  name name: String,
  run run: fn() -> Result(AssertionResult, String),
) -> UnitNode {
  Test(
    name: name,
    tags: [],
    kind: Unit,
    run: fn(_nil: Nil) { run() },
    timeout_ms: None,
  )
}

fn skipped_test_run(_nil: Nil) -> Result(AssertionResult, String) {
  Ok(AssertionSkipped)
}

/// Define a skipped test.
///
/// `skip` has the same shape as `it` so you can easily switch a test between
/// running and skipped without rewriting the test body.
///
/// The provided test body is preserved for that purpose, but it is **not
/// executed** while the test is skipped.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit.{describe, it, skip}
/// import gleam/io
///
/// pub fn tests() {
///   describe("Skipping tests", [
///     it("runs normally", fn() {
///       2 + 3
///       |> should
///       |> be_equal(5)
///       |> or_fail_with("2 + 3 should equal 5")
///     }),
///     skip("not implemented yet", fn() {
///       // This test is skipped - the body is preserved but not executed
///       100 + 200
///       |> should
///       |> be_equal(300)
///       |> or_fail_with("Should add large numbers")
///     }),
///     it("also runs normally", fn() {
///       0 + 0
///       |> should
///       |> be_equal(0)
///       |> or_fail_with("0 + 0 should equal 0")
///     }),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// ## Parameters
///
/// - `name`: the test name
/// - `run`: a **0-argument** function (accepted but never executed)
///
/// ## Returns
///
/// A `UnitNode` representing a skipped test (`AssertionSkipped`).
pub fn skip(
  name name: String,
  run run: fn() -> Result(AssertionResult, String),
) -> UnitNode {
  let node = it(name, run)
  case node {
    Test(name: name, tags: tags, kind: kind, run: _run, timeout_ms: timeout_ms) ->
      Test(
        name: name,
        tags: tags,
        kind: kind,
        run: skipped_test_run,
        timeout_ms: timeout_ms,
      )
    other -> other
  }
}

/// Run once before any tests in the current suite/group.
///
/// - Runs in a sandboxed process.
/// - If it returns `Error("message")`, all tests under this scope become
///   `SetupFailed`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_empty, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit.{
///   after_all, after_each, before_all, before_each, describe, it,
/// }
/// import gleam/io
///
/// pub fn tests() {
///   describe("Database tests", [
///     before_all(fn() {
///       // Start database once for all tests
///       start_database()
///     }),
///     before_each(fn() {
///       // Begin transaction before each test
///       begin_transaction()
///     }),
///     it("creates a record", fn() {
///       []
///       |> should
///       |> be_empty()
///       |> or_fail_with("Placeholder test")
///     }),
///     it("queries records", fn() {
///       []
///       |> should
///       |> be_empty()
///       |> or_fail_with("Placeholder test")
///     }),
///     after_each(fn() {
///       // Rollback transaction after each test
///       rollback_transaction()
///     }),
///     after_all(fn() {
///       // Stop database after all tests
///       stop_database()
///     }),
///   ])
/// }
///
/// fn start_database() {
///   Ok(Nil)
/// }
///
/// fn stop_database() {
///   Ok(Nil)
/// }
///
/// fn begin_transaction() {
///   Ok(Nil)
/// }
///
/// fn rollback_transaction() {
///   Ok(Nil)
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// ## Parameters
///
/// - `setup`: a **0-argument** function that returns `Ok(Nil)` on success or `Error(message)` on failure
///
/// ## Returns
///
/// A `UnitNode` representing a `before_all` hook.
pub fn before_all(setup setup: fn() -> Result(Nil, String)) -> UnitNode {
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
/// ```gleam
/// import dream_test/matchers.{be_empty, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit.{
///   after_all, after_each, before_all, before_each, describe, it,
/// }
/// import gleam/io
///
/// pub fn tests() {
///   describe("Database tests", [
///     before_all(fn() {
///       // Start database once for all tests
///       start_database()
///     }),
///     before_each(fn() {
///       // Begin transaction before each test
///       begin_transaction()
///     }),
///     it("creates a record", fn() {
///       []
///       |> should
///       |> be_empty()
///       |> or_fail_with("Placeholder test")
///     }),
///     it("queries records", fn() {
///       []
///       |> should
///       |> be_empty()
///       |> or_fail_with("Placeholder test")
///     }),
///     after_each(fn() {
///       // Rollback transaction after each test
///       rollback_transaction()
///     }),
///     after_all(fn() {
///       // Stop database after all tests
///       stop_database()
///     }),
///   ])
/// }
///
/// fn start_database() {
///   Ok(Nil)
/// }
///
/// fn stop_database() {
///   Ok(Nil)
/// }
///
/// fn begin_transaction() {
///   Ok(Nil)
/// }
///
/// fn rollback_transaction() {
///   Ok(Nil)
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// ## Parameters
///
/// - `setup`: a **0-argument** function that returns `Ok(Nil)` on success or `Error(message)` on failure
///
/// ## Returns
///
/// A `UnitNode` representing a `before_each` hook.
pub fn before_each(setup setup: fn() -> Result(Nil, String)) -> UnitNode {
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
/// ```gleam
/// import dream_test/matchers.{be_empty, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit.{
///   after_all, after_each, before_all, before_each, describe, it,
/// }
/// import gleam/io
///
/// pub fn tests() {
///   describe("Database tests", [
///     before_all(fn() {
///       // Start database once for all tests
///       start_database()
///     }),
///     before_each(fn() {
///       // Begin transaction before each test
///       begin_transaction()
///     }),
///     it("creates a record", fn() {
///       []
///       |> should
///       |> be_empty()
///       |> or_fail_with("Placeholder test")
///     }),
///     it("queries records", fn() {
///       []
///       |> should
///       |> be_empty()
///       |> or_fail_with("Placeholder test")
///     }),
///     after_each(fn() {
///       // Rollback transaction after each test
///       rollback_transaction()
///     }),
///     after_all(fn() {
///       // Stop database after all tests
///       stop_database()
///     }),
///   ])
/// }
///
/// fn start_database() {
///   Ok(Nil)
/// }
///
/// fn stop_database() {
///   Ok(Nil)
/// }
///
/// fn begin_transaction() {
///   Ok(Nil)
/// }
///
/// fn rollback_transaction() {
///   Ok(Nil)
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// ## Parameters
///
/// - `teardown`: a **0-argument** function that returns `Ok(Nil)` or `Error(message)`
///
/// ## Returns
///
/// A `UnitNode` representing an `after_each` hook.
pub fn after_each(teardown teardown: fn() -> Result(Nil, String)) -> UnitNode {
  AfterEach(fn(_nil: Nil) { teardown() })
}

/// Run once after all tests in the current scope.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_empty, or_fail_with, should}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit.{
///   after_all, after_each, before_all, before_each, describe, it,
/// }
/// import gleam/io
///
/// pub fn tests() {
///   describe("Database tests", [
///     before_all(fn() {
///       // Start database once for all tests
///       start_database()
///     }),
///     before_each(fn() {
///       // Begin transaction before each test
///       begin_transaction()
///     }),
///     it("creates a record", fn() {
///       []
///       |> should
///       |> be_empty()
///       |> or_fail_with("Placeholder test")
///     }),
///     it("queries records", fn() {
///       []
///       |> should
///       |> be_empty()
///       |> or_fail_with("Placeholder test")
///     }),
///     after_each(fn() {
///       // Rollback transaction after each test
///       rollback_transaction()
///     }),
///     after_all(fn() {
///       // Stop database after all tests
///       stop_database()
///     }),
///   ])
/// }
///
/// fn start_database() {
///   Ok(Nil)
/// }
///
/// fn stop_database() {
///   Ok(Nil)
/// }
///
/// fn begin_transaction() {
///   Ok(Nil)
/// }
///
/// fn rollback_transaction() {
///   Ok(Nil)
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// ## Parameters
///
/// - `teardown`: a **0-argument** function that returns `Ok(Nil)` or `Error(message)`
///
/// ## Returns
///
/// A `UnitNode` representing an `after_all` hook.
pub fn after_all(teardown teardown: fn() -> Result(Nil, String)) -> UnitNode {
  AfterAll(fn(_nil: Nil) { teardown() })
}

/// Attach tags to a node.
///
/// Tags propagate to descendant tests and are included in `TestResult.tags`.
/// Use tags to filter executed tests (e.g. in CI) with `runner.filter_tests`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{succeed}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/unit.{describe, it, with_tags}
/// import gleam/io
///
/// pub fn tests() {
///   describe("Tagged tests", [
///     it("fast", fn() { Ok(succeed()) })
///       |> with_tags(["unit", "fast"]),
///     it("slow", fn() { Ok(succeed()) })
///       |> with_tags(["integration", "slow"]),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
/// ## Parameters
///
/// - `node`: a test or group node to tag (tags do not apply to hooks)
/// - `tags`: tags to attach; group tags are inherited by descendant tests
///
/// ## Returns
///
/// The updated `UnitNode` with tags set.
pub fn with_tags(node node: UnitNode, tags tags: List(String)) -> UnitNode {
  case node {
    Group(name, _, children) ->
      Group(name: name, tags: tags, children: children)
    Test(name, _, kind, run, timeout_ms) ->
      Test(name: name, tags: tags, kind: kind, run: run, timeout_ms: timeout_ms)
    other -> other
  }
}
