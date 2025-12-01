//// Unit test DSL for dream_test.
////
//// This module provides a BDD-style syntax for defining tests: `describe`,
//// `it`, and lifecycle hooks (`before_all`, `before_each`, `after_each`,
//// `after_all`). Tests are organized hierarchically and converted to
//// runnable test cases or suites.
////
//// ## Quick Start
////
//// ```gleam
//// import dream_test/unit.{describe, it, to_test_cases}
//// import dream_test/assertions/should.{should, equal, or_fail_with}
//// import dream_test/runner.{run_all}
//// import dream_test/reporter/bdd.{report}
//// import gleam/io
////
//// pub fn main() {
////   tests()
////   |> to_test_cases("my_module_test")
////   |> run_all()
////   |> report(io.print)
//// }
////
//// pub fn tests() {
////   describe("Calculator", [
////     describe("add", [
////       it("adds positive numbers", fn() {
////         add(2, 3)
////         |> should()
////         |> equal(5)
////         |> or_fail_with("2 + 3 should equal 5")
////       }),
////       it("handles zero", fn() {
////         add(0, 5)
////         |> should()
////         |> equal(5)
////         |> or_fail_with("0 + 5 should equal 5")
////       }),
////     ]),
////   ])
//// }
//// ```
////
//// ## Output
////
//// ```text
//// Calculator
////   add
////     ✓ adds positive numbers
////     ✓ handles zero
////
//// Summary: 2 run, 0 failed, 2 passed
//// ```
////
//// ## Lifecycle Hooks
////
//// Setup and teardown logic for tests:
////
//// ```gleam
//// import dream_test/unit.{describe, it, before_each, after_each, to_test_cases}
//// import dream_test/types.{AssertionOk}
////
//// describe("Database", [
////   before_each(fn() {
////     reset_database()
////     AssertionOk
////   }),
////
////   it("creates users", fn() { ... }),
////   it("queries users", fn() { ... }),
////
////   after_each(fn() {
////     rollback()
////     AssertionOk
////   }),
//// ])
//// ```
////
//// | Hook          | Runs                              | Requires          |
//// |---------------|-----------------------------------|-------------------|
//// | `before_all`  | Once before all tests in group    | `to_test_suite`   |
//// | `before_each` | Before each test                  | Either mode       |
//// | `after_each`  | After each test (always)          | Either mode       |
//// | `after_all`   | Once after all tests in group     | `to_test_suite`   |
////
//// ## Two Execution Modes
////
//// **Flat mode** — faster, simpler, no `before_all`/`after_all`:
////
//// ```gleam
//// tests() |> to_test_cases("my_test") |> run_all()
//// ```
////
//// **Suite mode** — supports all hooks, preserves group structure:
////
//// ```gleam
//// tests() |> to_test_suite("my_test") |> run_suite()
//// ```
////
//// ## Nesting
////
//// You can nest `describe` blocks as deeply as needed. Each level adds to
//// the test's `full_name`, which the reporter uses for grouping output.
//// Lifecycle hooks are inherited by nested groups.
////
//// ```gleam
//// describe("User", [
////   before_each(fn() { create_user(); AssertionOk }),
////
////   describe("authentication", [
////     describe("with valid credentials", [
////       it("returns the user", fn() { ... }),
////       it("sets the session", fn() { ... }),
////     ]),
////     describe("with invalid credentials", [
////       it("returns an error", fn() { ... }),
////     ]),
////   ]),
//// ])
//// ```

import dream_test/types.{
  type AssertionResult, type TestCase, type TestSuite, type TestSuiteItem,
  AssertionSkipped, SingleTestConfig, SuiteGroup, SuiteTest, TestCase, TestSuite,
  Unit,
}
import gleam/list
import gleam/option.{None}

/// A node in the test tree.
///
/// This type represents either a single test (`ItTest`), a group of tests
/// (`DescribeGroup`), or a lifecycle hook. You typically don't construct
/// these directly—use `it`, `describe`, and the hook functions instead.
///
/// ## Variants
///
/// - `ItTest(name, run)` - A single test with a name and body function
/// - `DescribeGroup(name, children)` - A group of tests under a shared name
/// - `BeforeAll(setup)` - Runs once before all tests in the group
/// - `BeforeEach(setup)` - Runs before each test in the group
/// - `AfterEach(teardown)` - Runs after each test in the group
/// - `AfterAll(teardown)` - Runs once after all tests in the group
///
pub type UnitTest {
  ItTest(name: String, run: fn() -> AssertionResult)
  DescribeGroup(name: String, children: List(UnitTest))
  BeforeAll(setup: fn() -> AssertionResult)
  BeforeEach(setup: fn() -> AssertionResult)
  AfterEach(teardown: fn() -> AssertionResult)
  AfterAll(teardown: fn() -> AssertionResult)
}

/// Define a single test case.
///
/// The test body is a function that returns an `AssertionResult`. Use the
/// `should` API to build assertions that produce this result.
///
/// ## Example
///
/// ```gleam
/// it("calculates the sum correctly", fn() {
///   add(2, 3)
///   |> should()
///   |> equal(5)
///   |> or_fail_with("Expected 2 + 3 to equal 5")
/// })
/// ```
///
/// ## Naming Conventions
///
/// Good test names describe the expected behavior:
/// - ✓ "returns the user when credentials are valid"
/// - ✓ "rejects empty passwords"
/// - ✗ "test1"
/// - ✗ "works"
///
pub fn it(name: String, run: fn() -> AssertionResult) -> UnitTest {
  ItTest(name, run)
}

/// Skip a test case.
///
/// Use `skip` to temporarily disable a test without removing it. The test
/// will appear in reports with a `-` marker and won't affect the pass/fail
/// outcome.
///
/// This is designed to be a drop-in replacement for `it` — just change `it`
/// to `skip` to disable a test, and change it back when ready to run again.
///
/// ## Example
///
/// ```gleam
/// describe("Feature", [
///   it("works correctly", fn() { ... }),           // Runs normally
///   skip("needs fixing", fn() { ... }),            // Skipped
///   it("handles edge cases", fn() { ... }),        // Runs normally
/// ])
/// ```
///
/// ## Output
///
/// ```text
/// Feature
///   ✓ works correctly
///   - needs fixing
///   ✓ handles edge cases
///
/// Summary: 3 run, 0 failed, 2 passed, 1 skipped
/// ```
///
/// ## When to Use
///
/// - Test is broken and you need to fix it later
/// - Test depends on unimplemented functionality
/// - Test is flaky and needs investigation
/// - Temporarily disable slow tests during development
///
/// ## Note
///
/// The test body is preserved but not executed. This makes it easy to
/// toggle between `it` and `skip` without losing your test code.
///
pub fn skip(name: String, _run: fn() -> AssertionResult) -> UnitTest {
  ItTest(name, fn() { AssertionSkipped })
}

/// Group related tests under a common description.
///
/// Groups can be nested to any depth. The group names form a hierarchy that
/// appears in test output and failure messages.
///
/// ## Example
///
/// ```gleam
/// describe("String utilities", [
///   describe("trim", [
///     it("removes leading spaces", fn() { ... }),
///     it("removes trailing spaces", fn() { ... }),
///   ]),
///   describe("split", [
///     it("splits on delimiter", fn() { ... }),
///   ]),
/// ])
/// ```
///
/// ## Output
///
/// ```text
/// String utilities
///   trim
///     ✓ removes leading spaces
///     ✓ removes trailing spaces
///   split
///     ✓ splits on delimiter
/// ```
///
pub fn describe(name: String, children: List(UnitTest)) -> UnitTest {
  DescribeGroup(name, children)
}

/// Run setup once before all tests in the current `describe` block.
///
/// Use `before_all` when you have expensive setup that should happen once
/// for the entire group rather than before each individual test.
///
/// ## When to Use
///
/// - Starting a database server
/// - Creating temporary files or directories
/// - Launching external services
/// - Any setup that's slow or has side effects you want to share
///
/// ## Execution Behavior
///
/// - Runs exactly once, before the first test in the group
/// - If it returns `AssertionFailed`, all tests in the group are skipped
///   and marked as `SetupFailed`
/// - Nested `describe` blocks each run their own `before_all` hooks
///
/// ## Example
///
/// ```gleam
/// import dream_test/unit.{describe, it, before_all, after_all, to_test_suite}
/// import dream_test/runner.{run_suite}
/// import dream_test/types.{AssertionOk}
///
/// describe("Database integration", [
///   before_all(fn() {
///     // This runs once before any test
///     start_test_database()
///     run_migrations()
///     AssertionOk
///   }),
///
///   it("creates users", fn() { ... }),
///   it("queries users", fn() { ... }),
///   it("updates users", fn() { ... }),
///
///   after_all(fn() {
///     stop_test_database()
///     AssertionOk
///   }),
/// ])
/// |> to_test_suite("db_test")
/// |> run_suite()
/// ```
///
/// ## Important: Requires Suite Mode
///
/// `before_all` hooks only work with `to_test_suite` + `run_suite`.
/// When using `to_test_cases` + `run_all`, they are silently ignored.
///
/// This is because flat mode loses the group structure needed to know
/// where "all tests in a group" begins and ends.
///
pub fn before_all(setup: fn() -> AssertionResult) -> UnitTest {
  BeforeAll(setup)
}

/// Run setup before each test in the current `describe` block.
///
/// Use `before_each` when tests need a fresh, isolated state. This is the
/// most commonly used lifecycle hook.
///
/// ## When to Use
///
/// - Resetting database state between tests
/// - Creating fresh test fixtures
/// - Beginning a transaction to rollback later
/// - Clearing caches or in-memory state
///
/// ## Execution Behavior
///
/// - Runs before every test in the group and all nested groups
/// - If it returns `AssertionFailed`, the test is skipped and marked `SetupFailed`
/// - Multiple `before_each` hooks in the same group run in declaration order
///
/// ## Example
///
/// ```gleam
/// import dream_test/unit.{describe, it, before_each, after_each, to_test_cases}
/// import dream_test/runner.{run_all}
/// import dream_test/types.{AssertionOk}
///
/// describe("Shopping cart", [
///   before_each(fn() {
///     // Fresh cart for each test
///     clear_cart()
///     AssertionOk
///   }),
///
///   it("starts empty", fn() {
///     get_cart_items()
///     |> should()
///     |> equal([])
///     |> or_fail_with("New cart should be empty")
///   }),
///
///   it("adds items", fn() {
///     add_to_cart("apple")
///     get_cart_items()
///     |> should()
///     |> contain("apple")
///     |> or_fail_with("Cart should contain apple")
///   }),
/// ])
/// |> to_test_cases("cart_test")
/// |> run_all()
/// ```
///
/// ## Hook Inheritance
///
/// Nested `describe` blocks inherit parent `before_each` hooks. Parent hooks
/// run first (outer-to-inner order):
///
/// ```gleam
/// describe("Outer", [
///   before_each(fn() { setup_outer(); AssertionOk }),  // Runs 1st
///
///   describe("Inner", [
///     before_each(fn() { setup_inner(); AssertionOk }),  // Runs 2nd
///     it("test", fn() { ... }),
///   ]),
/// ])
/// ```
///
/// ## Works in Both Modes
///
/// Unlike `before_all`, `before_each` works with both `to_test_cases`
/// and `to_test_suite`. Use whichever fits your needs.
///
pub fn before_each(setup: fn() -> AssertionResult) -> UnitTest {
  BeforeEach(setup)
}

/// Run teardown after each test in the current `describe` block.
///
/// Use `after_each` to clean up resources created during a test. This hook
/// runs even if the test fails, ensuring reliable cleanup.
///
/// ## When to Use
///
/// - Rolling back database transactions
/// - Deleting temporary files created by the test
/// - Resetting global state or mocks
/// - Closing connections or releasing resources
///
/// ## Execution Behavior
///
/// - Runs after every test in the group and all nested groups
/// - **Always runs**, even if the test or `before_each` hooks fail
/// - Multiple `after_each` hooks in the same group run in reverse declaration order
///
/// ## Example
///
/// ```gleam
/// import dream_test/unit.{describe, it, before_each, after_each, to_test_cases}
/// import dream_test/runner.{run_all}
/// import dream_test/types.{AssertionOk}
///
/// describe("File operations", [
///   before_each(fn() {
///     create_temp_directory()
///     AssertionOk
///   }),
///
///   after_each(fn() {
///     // Always clean up, even if test crashes
///     delete_temp_directory()
///     AssertionOk
///   }),
///
///   it("writes files", fn() { ... }),
///   it("reads files", fn() { ... }),
/// ])
/// |> to_test_cases("file_test")
/// |> run_all()
/// ```
///
/// ## Hook Inheritance
///
/// Nested `describe` blocks inherit parent `after_each` hooks. Child hooks
/// run first (inner-to-outer order, reverse of `before_each`):
///
/// ```gleam
/// describe("Outer", [
///   after_each(fn() { teardown_outer(); AssertionOk }),  // Runs 2nd
///
///   describe("Inner", [
///     after_each(fn() { teardown_inner(); AssertionOk }),  // Runs 1st
///     it("test", fn() { ... }),
///   ]),
/// ])
/// ```
///
/// ## Works in Both Modes
///
/// Like `before_each`, `after_each` works with both `to_test_cases`
/// and `to_test_suite`.
///
pub fn after_each(teardown: fn() -> AssertionResult) -> UnitTest {
  AfterEach(teardown)
}

/// Run teardown once after all tests in the current `describe` block.
///
/// Use `after_all` to clean up expensive resources that were set up by
/// `before_all`. This hook runs once after all tests complete, regardless
/// of whether tests passed or failed.
///
/// ## When to Use
///
/// - Stopping a database server started by `before_all`
/// - Removing temporary directories
/// - Shutting down external services
/// - Any cleanup that corresponds to `before_all` setup
///
/// ## Execution Behavior
///
/// - Runs exactly once, after the last test in the group completes
/// - **Always runs**, even if tests fail or `before_all` fails
/// - Nested `describe` blocks each run their own `after_all` hooks
///
/// ## Example
///
/// ```gleam
/// import dream_test/unit.{describe, it, before_all, after_all, to_test_suite}
/// import dream_test/runner.{run_suite}
/// import dream_test/types.{AssertionOk}
///
/// describe("External API integration", [
///   before_all(fn() {
///     start_mock_server(port: 8080)
///     AssertionOk
///   }),
///
///   it("fetches users", fn() { ... }),
///   it("creates users", fn() { ... }),
///   it("handles errors", fn() { ... }),
///
///   after_all(fn() {
///     // Clean up even if tests failed
///     stop_mock_server()
///     AssertionOk
///   }),
/// ])
/// |> to_test_suite("api_test")
/// |> run_suite()
/// ```
///
/// ## Complete Lifecycle Example
///
/// Here's a complete example showing all four hooks working together:
///
/// ```gleam
/// describe("Database tests", [
///   // Once at start: start the database
///   before_all(fn() { start_db(); AssertionOk }),
///
///   // Before each test: begin a transaction
///   before_each(fn() { begin_transaction(); AssertionOk }),
///
///   it("creates records", fn() { ... }),
///   it("queries records", fn() { ... }),
///
///   // After each test: rollback the transaction
///   after_each(fn() { rollback_transaction(); AssertionOk }),
///
///   // Once at end: stop the database
///   after_all(fn() { stop_db(); AssertionOk }),
/// ])
/// ```
///
/// ## Important: Requires Suite Mode
///
/// `after_all` hooks only work with `to_test_suite` + `run_suite`.
/// When using `to_test_cases` + `run_all`, they are silently ignored.
///
pub fn after_all(teardown: fn() -> AssertionResult) -> UnitTest {
  AfterAll(teardown)
}

/// Context for tracking inherited hooks during tree traversal.
///
/// This is used internally when converting a test tree to test cases.
/// Hooks are inherited from parent describe blocks.
///
type HookContext {
  HookContext(
    /// before_each hooks in outer-to-inner order
    before_each_hooks: List(fn() -> AssertionResult),
    /// after_each hooks in inner-to-outer order
    after_each_hooks: List(fn() -> AssertionResult),
  )
}

fn empty_hook_context() -> HookContext {
  HookContext(before_each_hooks: [], after_each_hooks: [])
}

/// Convert a test tree into a flat list of runnable test cases.
///
/// This function walks the `UnitTest` tree and produces `TestCase` values
/// that the runner can execute. Each test case includes:
///
/// - `name` - The test's own name (from `it`)
/// - `full_name` - The complete path including all `describe` ancestors
/// - `tags` - Currently empty (tag support coming soon)
/// - `kind` - Set to `Unit` for all tests from this DSL
/// - `before_each_hooks` - Inherited hooks to run before the test
/// - `after_each_hooks` - Inherited hooks to run after the test
///
/// ## Hook Handling
///
/// - `before_each`/`after_each` hooks are collected and attached to each test
/// - `before_all`/`after_all` hooks are ignored (use `to_test_suite` instead)
///
/// ## Example
///
/// ```gleam
/// let test_cases =
///   describe("Math", [
///     it("adds", fn() { ... }),
///     it("subtracts", fn() { ... }),
///   ])
///   |> to_test_cases("math_test")
///
/// // test_cases is now a List(TestCase) ready for run_all()
/// ```
///
/// ## Parameters
///
/// - `module_name` - The name of the test module (used for identification)
/// - `root` - The root `UnitTest` node (typically from `describe`)
///
pub fn to_test_cases(module_name: String, root: UnitTest) -> List(TestCase) {
  let context = empty_hook_context()
  to_test_cases_from_unit_test(module_name, [], context, root, [])
}

fn to_test_cases_from_unit_test(
  module_name: String,
  name_prefix: List(String),
  hook_context: HookContext,
  node: UnitTest,
  accumulated: List(TestCase),
) -> List(TestCase) {
  case node {
    ItTest(name, run) ->
      build_it_test_case(name_prefix, name, run, hook_context, accumulated)

    DescribeGroup(name, children) -> {
      let new_prefix = list.append(name_prefix, [name])
      let group_hooks = collect_hooks_from_children(children, hook_context)
      to_test_cases_from_list(
        module_name,
        new_prefix,
        group_hooks,
        children,
        accumulated,
      )
    }

    // before_all and after_all are ignored in flat mode
    BeforeAll(_) -> accumulated
    AfterAll(_) -> accumulated

    // before_each and after_each at the root level (outside describe) are ignored
    BeforeEach(_) -> accumulated
    AfterEach(_) -> accumulated
  }
}

/// Collect hooks from a list of children and merge with inherited hooks.
fn collect_hooks_from_children(
  children: List(UnitTest),
  inherited: HookContext,
) -> HookContext {
  collect_hooks_from_list(children, inherited)
}

fn collect_hooks_from_list(
  remaining: List(UnitTest),
  context: HookContext,
) -> HookContext {
  case remaining {
    [] -> context
    [head, ..tail] -> {
      let updated = collect_hook_from_node(head, context)
      collect_hooks_from_list(tail, updated)
    }
  }
}

fn collect_hook_from_node(node: UnitTest, context: HookContext) -> HookContext {
  case node {
    BeforeEach(setup) -> {
      // Append to maintain outer-to-inner order
      let hooks = list.append(context.before_each_hooks, [setup])
      HookContext(..context, before_each_hooks: hooks)
    }
    AfterEach(teardown) -> {
      // Prepend to maintain inner-to-outer order
      HookContext(..context, after_each_hooks: [
        teardown,
        ..context.after_each_hooks
      ])
    }
    // Other nodes don't affect hooks
    _ -> context
  }
}

fn build_it_test_case(
  name_prefix: List(String),
  name: String,
  run: fn() -> AssertionResult,
  hook_context: HookContext,
  accumulated: List(TestCase),
) -> List(TestCase) {
  let full_name = list.append(name_prefix, [name])
  let config =
    SingleTestConfig(
      name: name,
      full_name: full_name,
      tags: [],
      kind: Unit,
      run: run,
      timeout_ms: None,
      before_each_hooks: hook_context.before_each_hooks,
      after_each_hooks: hook_context.after_each_hooks,
    )
  let test_case = TestCase(config)
  [test_case, ..accumulated]
}

fn to_test_cases_from_list(
  module_name: String,
  name_prefix: List(String),
  hook_context: HookContext,
  remaining: List(UnitTest),
  accumulated: List(TestCase),
) -> List(TestCase) {
  case remaining {
    [] -> list.reverse(accumulated)

    [head, ..tail] -> {
      let updated =
        to_test_cases_from_unit_test(
          module_name,
          name_prefix,
          hook_context,
          head,
          accumulated,
        )
      to_test_cases_from_list(
        module_name,
        name_prefix,
        hook_context,
        tail,
        updated,
      )
    }
  }
}

// =============================================================================
// Test Suite Conversion (for before_all/after_all support)
// =============================================================================

/// Convert a test tree into a structured test suite.
///
/// Use `to_test_suite` when you need `before_all` or `after_all` hooks.
/// Unlike `to_test_cases`, this preserves the group hierarchy required
/// for once-per-group semantics.
///
/// ## When to Use Each Mode
///
/// | Scenario                                    | Function         | Runner       |
/// |---------------------------------------------|------------------|--------------|
/// | Simple tests, no hooks                      | `to_test_cases`  | `run_all`    |
/// | Only `before_each`/`after_each`             | `to_test_cases`  | `run_all`    |
/// | Need `before_all` or `after_all`            | `to_test_suite`  | `run_suite`  |
/// | Expensive setup shared across tests         | `to_test_suite`  | `run_suite`  |
///
/// ## How It Works
///
/// ```text
/// describe("A", [                    TestSuite("A")
///   before_all(setup),          →      before_all: [setup]
///   it("test1", ...),                  items: [
///   describe("B", [                      SuiteTest(test1),
///     it("test2", ...),                  SuiteGroup(TestSuite("B", ...))
///   ]),                                ]
/// ])
/// ```
///
/// The tree structure is preserved, allowing the runner to execute
/// `before_all` before entering a group and `after_all` after leaving.
///
/// ## Example
///
/// ```gleam
/// import dream_test/unit.{describe, it, before_all, after_all, to_test_suite}
/// import dream_test/runner.{run_suite}
/// import dream_test/reporter/bdd.{report}
/// import dream_test/types.{AssertionOk}
/// import gleam/io
///
/// pub fn main() {
///   tests()
///   |> to_test_suite("integration_test")
///   |> run_suite()
///   |> report(io.print)
/// }
///
/// pub fn tests() {
///   describe("Payment processing", [
///     before_all(fn() {
///       start_payment_gateway_mock()
///       AssertionOk
///     }),
///
///     describe("successful payments", [
///       it("processes credit cards", fn() { ... }),
///       it("processes debit cards", fn() { ... }),
///     ]),
///
///     describe("failed payments", [
///       it("handles declined cards", fn() { ... }),
///       it("handles network errors", fn() { ... }),
///     ]),
///
///     after_all(fn() {
///       stop_payment_gateway_mock()
///       AssertionOk
///     }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `module_name` - Name of the test module (appears in output)
/// - `root` - The root `UnitTest` node (typically from `describe`)
///
/// ## Returns
///
/// A `TestSuite` that can be executed with `run_suite` or `run_suite_with_config`.
///
pub fn to_test_suite(module_name: String, root: UnitTest) -> TestSuite {
  let context = empty_hook_context()
  to_suite_from_unit_test(module_name, [], context, root)
}

fn to_suite_from_unit_test(
  module_name: String,
  name_prefix: List(String),
  inherited_hooks: HookContext,
  node: UnitTest,
) -> TestSuite {
  case node {
    DescribeGroup(name, children) -> {
      let full_name = list.append(name_prefix, [name])
      build_suite_from_describe(
        module_name,
        full_name,
        inherited_hooks,
        children,
      )
    }

    // If root is not a describe, wrap it in a synthetic suite
    ItTest(name, run) -> {
      let full_name = list.append(name_prefix, [name])
      let test_case =
        build_single_test_case(full_name, name, run, inherited_hooks)
      TestSuite(
        name: module_name,
        full_name: [module_name],
        before_all_hooks: [],
        after_all_hooks: [],
        items: [SuiteTest(test_case)],
      )
    }

    // Hooks at root level are ignored
    BeforeAll(_) | BeforeEach(_) | AfterEach(_) | AfterAll(_) ->
      TestSuite(
        name: module_name,
        full_name: [module_name],
        before_all_hooks: [],
        after_all_hooks: [],
        items: [],
      )
  }
}

fn build_suite_from_describe(
  module_name: String,
  full_name: List(String),
  inherited_hooks: HookContext,
  children: List(UnitTest),
) -> TestSuite {
  // Collect hooks from this level
  let suite_hooks = collect_suite_hooks(children)
  let group_hooks = collect_hooks_from_children(children, inherited_hooks)

  // Build items from children
  let items =
    build_suite_items(module_name, full_name, group_hooks, children, [])

  // Extract name from full_name
  let name = extract_last_name(full_name)

  TestSuite(
    name: name,
    full_name: full_name,
    before_all_hooks: suite_hooks.before_all,
    after_all_hooks: suite_hooks.after_all,
    items: items,
  )
}

/// Hooks specific to a suite (before_all/after_all)
type SuiteHooks {
  SuiteHooks(
    before_all: List(fn() -> AssertionResult),
    after_all: List(fn() -> AssertionResult),
  )
}

fn collect_suite_hooks(children: List(UnitTest)) -> SuiteHooks {
  collect_suite_hooks_from_list(
    children,
    SuiteHooks(before_all: [], after_all: []),
  )
}

fn collect_suite_hooks_from_list(
  remaining: List(UnitTest),
  hooks: SuiteHooks,
) -> SuiteHooks {
  case remaining {
    [] ->
      SuiteHooks(
        before_all: list.reverse(hooks.before_all),
        after_all: list.reverse(hooks.after_all),
      )
    [head, ..tail] -> {
      let updated = collect_suite_hook(head, hooks)
      collect_suite_hooks_from_list(tail, updated)
    }
  }
}

fn collect_suite_hook(node: UnitTest, hooks: SuiteHooks) -> SuiteHooks {
  case node {
    BeforeAll(setup) ->
      SuiteHooks(..hooks, before_all: [setup, ..hooks.before_all])
    AfterAll(teardown) ->
      SuiteHooks(..hooks, after_all: [teardown, ..hooks.after_all])
    _ -> hooks
  }
}

fn build_suite_items(
  module_name: String,
  name_prefix: List(String),
  hook_context: HookContext,
  remaining: List(UnitTest),
  accumulated: List(TestSuiteItem),
) -> List(TestSuiteItem) {
  case remaining {
    [] -> list.reverse(accumulated)
    [head, ..tail] -> {
      let new_items =
        build_suite_item(module_name, name_prefix, hook_context, head)
      let updated = list.append(list.reverse(new_items), accumulated)
      build_suite_items(module_name, name_prefix, hook_context, tail, updated)
    }
  }
}

fn build_suite_item(
  module_name: String,
  name_prefix: List(String),
  hook_context: HookContext,
  node: UnitTest,
) -> List(TestSuiteItem) {
  case node {
    ItTest(name, run) -> {
      let full_name = list.append(name_prefix, [name])
      let test_case = build_single_test_case(full_name, name, run, hook_context)
      [SuiteTest(test_case)]
    }

    DescribeGroup(name, children) -> {
      let full_name = list.append(name_prefix, [name])
      let nested_suite =
        build_suite_from_describe(
          module_name,
          full_name,
          hook_context,
          children,
        )
      [SuiteGroup(nested_suite)]
    }

    // Hooks are collected separately, not items
    BeforeAll(_) | BeforeEach(_) | AfterEach(_) | AfterAll(_) -> []
  }
}

fn build_single_test_case(
  full_name: List(String),
  name: String,
  run: fn() -> AssertionResult,
  hook_context: HookContext,
) -> TestCase {
  let config =
    SingleTestConfig(
      name: name,
      full_name: full_name,
      tags: [],
      kind: Unit,
      run: run,
      timeout_ms: None,
      before_each_hooks: hook_context.before_each_hooks,
      after_each_hooks: hook_context.after_each_hooks,
    )
  TestCase(config)
}

fn extract_last_name(full_name: List(String)) -> String {
  case list.reverse(full_name) {
    [last, ..] -> last
    [] -> ""
  }
}
