//// Core types for dream_test.
////
//// This module defines the data structures used throughout the framework.
//// Most users won't need to interact with these types directly—they're used
//// internally by the DSL, runner, and reporters.
////
//// ## Type Overview
////
//// | Type               | Purpose                                          |
//// |--------------------|--------------------------------------------------|
//// | `Status`           | Test outcome (Passed, Failed, etc.)              |
//// | `TestKind`         | Type of test (Unit, Integration, Gherkin)        |
//// | `TestResult`       | Complete result of running a test                |
//// | `AssertionResult`  | Pass/fail result of an assertion chain           |
//// | `MatchResult(a)`   | Intermediate result during assertion chaining    |
//// | `AssertionFailure` | Details about a failed assertion                 |
////
//// ## For Custom Matcher Authors
////
//// If you're writing custom matchers, you'll work with `MatchResult(a)`:
////
//// ```gleam
//// import dream_test/types.{type MatchResult, MatchOk, MatchFailed, AssertionFailure}
////
//// pub fn be_positive(result: MatchResult(Int)) -> MatchResult(Int) {
////   case result {
////     MatchFailed(f) -> MatchFailed(f)
////     MatchOk(n) -> check_positive(n)
////   }
//// }
////
//// fn check_positive(n: Int) -> MatchResult(Int) {
////   case n > 0 {
////     True -> MatchOk(n)
////     False -> MatchFailed(AssertionFailure(...))
////   }
//// }
//// ```

import gleam/option.{type Option}

/// The outcome of a test.
///
/// After a test runs, it has one of these statuses:
///
/// | Status        | Meaning                                           |
/// |---------------|---------------------------------------------------|
/// | `Passed`      | All assertions succeeded                          |
/// | `Failed`      | One or more assertions failed                     |
/// | `Skipped`     | Test was marked to skip (not yet implemented)     |
/// | `Pending`     | Test is a placeholder (not yet implemented)       |
/// | `TimedOut`    | Test exceeded its timeout and was killed          |
/// | `SetupFailed` | A lifecycle hook failed; test never ran           |
///
/// ## SetupFailed Explained
///
/// When a `before_each` or `before_all` hook returns `AssertionFailed`,
/// the test (or all tests in the group) are marked as `SetupFailed`.
/// This indicates the test didn't fail on its own—it never had a chance
/// to run because its setup failed.
///
/// ```gleam
/// describe("Database", [
///   before_all(fn() {
///     case connect_to_database() {
///       Ok(_) -> AssertionOk
///       Error(_) -> AssertionFailed(...)  // All tests become SetupFailed
///     }
///   }),
///   it("test1", fn() { ... }),  // Never runs → SetupFailed
///   it("test2", fn() { ... }),  // Never runs → SetupFailed
/// ])
/// ```
///
/// The `failures` field in `TestResult` will contain the hook's failure
/// details, so you can see what went wrong.
///
pub type Status {
  Passed
  Failed
  Skipped
  Pending
  TimedOut
  SetupFailed
}

/// The kind/category of a test.
///
/// Used to distinguish between different testing styles:
///
/// - `Unit` - Standard unit tests from `describe`/`it`
/// - `Integration` - Integration tests (for future use)
/// - `GherkinScenario(id)` - Tests from Gherkin features (inline DSL or `.feature` files)
///
pub type TestKind {
  Unit
  Integration
  GherkinScenario(String)
}

/// Structured details about why an assertion failed.
///
/// Each variant provides context appropriate to the type of assertion.
/// Reporters use this to format helpful error messages.
///
/// ## Variants
///
/// - `EqualityFailure` - For `equal`/`not_equal` comparisons
/// - `BooleanFailure` - For `be_true`/`be_false`
/// - `OptionFailure` - For `be_some`/`be_none`
/// - `ResultFailure` - For `be_ok`/`be_error`
/// - `CollectionFailure` - For `contain`/`have_length`/`be_empty`
/// - `ComparisonFailure` - For `be_greater_than`/`be_less_than`/etc.
/// - `StringMatchFailure` - For `start_with`/`end_with`/`contain_string`
/// - `SnapshotFailure` - For `match_snapshot` comparisons
/// - `CustomMatcherFailure` - For user-defined matchers
///
pub type FailurePayload {
  EqualityFailure(actual: String, expected: String)
  BooleanFailure(actual: Bool, expected: Bool)
  OptionFailure(actual: String, expected_some: Bool)
  ResultFailure(actual: String, expected_ok: Bool)
  CollectionFailure(actual: String, expected: String, operation: String)
  ComparisonFailure(actual: String, expected: String, operator: String)
  StringMatchFailure(actual: String, pattern: String, operation: String)
  SnapshotFailure(
    actual: String,
    expected: String,
    snapshot_path: String,
    is_missing: Bool,
  )
  CustomMatcherFailure(actual: String, description: String)
}

/// Complete information about a failed assertion.
///
/// Contains the operator name, user message, and optional structured payload.
///
/// ## Fields
///
/// - `operator` - Name of the matcher that failed (e.g., "equal", "be_some")
/// - `message` - User-provided failure message from `or_fail_with`
/// - `payload` - Optional structured details for rich error reporting
///
pub type AssertionFailure {
  AssertionFailure(
    operator: String,
    message: String,
    payload: Option(FailurePayload),
  )
}

/// The final result of an assertion chain.
///
/// This is what `or_fail_with` returns. Test runners use this to determine
/// whether a test passed or failed.
///
/// ## Variants
///
/// - `AssertionOk` - The assertion chain passed
/// - `AssertionFailed(failure)` - The assertion chain failed with details
/// - `AssertionSkipped` - The test was skipped (used by `skip` function)
///
/// ## Example
///
/// Most users won't construct this directly. It's returned by `or_fail_with`:
///
/// ```gleam
/// let result: AssertionResult =
///   42
///   |> should()
///   |> equal(42)
///   |> or_fail_with("Should be 42")
/// // result == AssertionOk
/// ```
///
pub type AssertionResult {
  AssertionOk
  AssertionFailed(AssertionFailure)
  AssertionSkipped
}

/// Intermediate result during assertion chaining.
///
/// This type carries a value through a chain of matchers. Each matcher receives
/// a `MatchResult`, checks or transforms the value, and returns a new `MatchResult`.
///
/// ## How Chaining Works
///
/// ```gleam
/// Some(42)           // Start with a value
/// |> should()        // -> MatchOk(Some(42))
/// |> be_some()       // -> MatchOk(42)  (unwrapped!)
/// |> equal(42)       // -> MatchOk(42)
/// |> or_fail_with()  // -> AssertionOk
/// ```
///
/// If any matcher fails, the `MatchFailed` propagates through the rest of
/// the chain without executing further checks.
///
/// ## For Custom Matchers
///
/// When writing a custom matcher, follow this pattern:
///
/// ```gleam
/// pub fn be_even(result: MatchResult(Int)) -> MatchResult(Int) {
///   case result {
///     MatchFailed(failure) -> MatchFailed(failure)  // Propagate failure
///     MatchOk(value) -> check_is_even(value)        // Check the value
///   }
/// }
/// ```
///
pub type MatchResult(a) {
  MatchOk(a)
  MatchFailed(AssertionFailure)
}

/// Convert a MatchResult to an AssertionResult.
///
/// This discards the value and returns just the pass/fail status.
/// Used internally by `or_fail_with`.
///
/// ## Example
///
/// ```gleam
/// let match_result = MatchOk(42)
/// let assertion_result = to_assertion_result(match_result)
/// // assertion_result == AssertionOk
/// ```
///
pub fn to_assertion_result(result: MatchResult(a)) -> AssertionResult {
  case result {
    MatchOk(_) -> AssertionOk
    MatchFailed(failure) -> AssertionFailed(failure)
  }
}

/// Coverage data for a single module.
///
/// *Note: Coverage reporting is planned but not yet implemented.*
///
pub type ModuleCoverage {
  ModuleCoverage(
    module_: String,
    percent: Float,
    covered_lines: Int,
    total_lines: Int,
  )
}

/// Summary of code coverage across all modules.
///
/// *Note: Coverage reporting is planned but not yet implemented.*
///
pub type CoverageSummary {
  CoverageSummary(by_module: List(ModuleCoverage))
}

/// Complete result of running a test.
///
/// Contains everything needed to report on a test's outcome.
///
/// ## Fields
///
/// - `name` - The test's own name (from `it`)
/// - `full_name` - Complete path including `describe` ancestors
/// - `status` - Whether the test passed, failed, etc.
/// - `duration_ms` - How long the test took in milliseconds
/// - `tags` - Test tags for filtering
/// - `failures` - List of assertion failures (empty if passed)
/// - `kind` - Type of test (Unit, Integration, Gherkin)
///
/// ## Example
///
/// After running tests, you get a list of these:
///
/// ```gleam
/// let results = run_all(test_cases)
/// // results: List(TestResult)
///
/// list.each(results, fn(result) {
///   case result.status {
///     Passed -> io.println("✓ " <> result.name)
///     Failed -> io.println("✗ " <> result.name)
///     _ -> Nil
///   }
/// })
/// ```
///
pub type TestResult {
  TestResult(
    name: String,
    full_name: List(String),
    status: Status,
    duration_ms: Int,
    tags: List(String),
    failures: List(AssertionFailure),
    kind: TestKind,
  )
}

/// Configuration for a single test.
///
/// This is the internal representation of a test before it's run.
/// Most users won't create this directly—use `describe`/`it` instead.
///
/// ## Fields
///
/// - `name` - The test's name
/// - `full_name` - Complete path including parent groups
/// - `tags` - Tags for filtering with `RunnerConfig.test_filter`
/// - `kind` - Type of test (Unit, Integration, Gherkin)
/// - `run` - The test function to execute
/// - `timeout_ms` - Optional per-test timeout override
/// - `before_each_hooks` - Hooks to run before the test (outer-to-inner order)
/// - `after_each_hooks` - Hooks to run after the test (inner-to-outer order)
///
pub type SingleTestConfig {
  SingleTestConfig(
    name: String,
    full_name: List(String),
    tags: List(String),
    kind: TestKind,
    run: fn() -> AssertionResult,
    /// Optional per-test timeout override in milliseconds.
    /// If None, uses the runner's default timeout.
    timeout_ms: Option(Int),
    /// Hooks to run before the test, in outer-to-inner order.
    before_each_hooks: List(fn() -> AssertionResult),
    /// Hooks to run after the test, in inner-to-outer order.
    after_each_hooks: List(fn() -> AssertionResult),
  )
}

/// A runnable test case.
///
/// Wraps a `SingleTestConfig`. This is what the runner actually executes.
///
pub type TestCase {
  TestCase(SingleTestConfig)
}

/// A structured test suite preserving group hierarchy.
///
/// Unlike a flat `List(TestCase)`, a `TestSuite` maintains the tree structure
/// of your `describe` blocks. This enables `before_all`/`after_all` hooks,
/// which need to know where groups begin and end.
///
/// ## When You Need This
///
/// Most tests don't need `TestSuite`. Use it when you have:
///
/// - Expensive setup you want to share across tests (database servers, etc.)
/// - Resources that should be created once and cleaned up once
/// - Integration tests with external services
///
/// ## How It's Structured
///
/// ```text
/// TestSuite("Database tests")
/// ├── before_all_hooks: [start_db]
/// ├── items:
/// │   ├── SuiteTest("creates users")
/// │   ├── SuiteTest("queries users")
/// │   └── SuiteGroup(TestSuite("error cases"))
/// │       ├── before_all_hooks: []
/// │       ├── items:
/// │       │   ├── SuiteTest("handles not found")
/// │       │   └── SuiteTest("handles timeout")
/// │       └── after_all_hooks: []
/// └── after_all_hooks: [stop_db]
/// ```
///
/// ## Creating a TestSuite
///
/// Don't construct this directly. Use `to_test_suite` from the unit module:
///
/// ```gleam
/// import dream_test/unit.{describe, it, before_all, to_test_suite}
///
/// describe("My tests", [
///   before_all(fn() { setup(); AssertionOk }),
///   it("test one", fn() { ... }),
/// ])
/// |> to_test_suite("my_module_test")
/// ```
///
/// ## Executing a TestSuite
///
/// Use `run_suite` or `run_suite_with_config`:
///
/// ```gleam
/// suite
/// |> run_suite()
/// |> report(io.print)
/// ```
///
/// ## Fields
///
/// - `name` - The group's name (from `describe`)
/// - `full_name` - Complete path including parent groups (for reporting)
/// - `before_all_hooks` - Run once before any test in this group
/// - `after_all_hooks` - Run once after all tests in this group complete
/// - `items` - The tests and nested groups contained in this suite
///
pub type TestSuite {
  TestSuite(
    name: String,
    full_name: List(String),
    before_all_hooks: List(fn() -> AssertionResult),
    after_all_hooks: List(fn() -> AssertionResult),
    items: List(TestSuiteItem),
  )
}

/// An item within a test suite: either a single test or a nested group.
///
/// This type enables the recursive structure of `TestSuite`. You won't
/// typically construct these directly—they're created by `to_test_suite`.
///
/// ## Variants
///
/// - `SuiteTest(TestCase)` - A single test to execute
/// - `SuiteGroup(TestSuite)` - A nested group with its own hooks
///
/// ## Execution Order
///
/// When a suite is executed, items are processed in order:
///
/// 1. All `SuiteTest` items run in parallel (up to `max_concurrency`)
/// 2. `SuiteGroup` items are processed after tests complete
/// 3. Each nested group runs its own `before_all`/`after_all` hooks
///
pub type TestSuiteItem {
  /// A single test case to run.
  SuiteTest(TestCase)
  /// A nested group with its own hooks.
  SuiteGroup(TestSuite)
}

/// Derive a Status from a list of failures.
///
/// Returns `Passed` if there are no failures, `Failed` otherwise.
///
/// ## Example
///
/// ```gleam
/// status_from_failures([])  // -> Passed
/// status_from_failures([some_failure])  // -> Failed
/// ```
///
pub fn status_from_failures(failures: List(AssertionFailure)) -> Status {
  case failures {
    [] -> Passed
    _ -> Failed
  }
}
