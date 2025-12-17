//// Core types for dream_test.
////
//// This module defines the data structures used throughout the framework.
//// Most users won’t need to construct these values directly—`dream_test/unit`,
//// `dream_test/runner`, and the reporter modules create them for you.
////
//// You *will* want to read this module if you are:
////
//// - writing custom matchers (you’ll work with `MatchResult(a)` and `AssertionFailure`)
//// - building a custom reporter (you’ll consume `TestResult`)
//// - filtering results in CI (you’ll inspect `TestResult.tags`, `TestResult.status`, etc.)
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

/// Error type for test execution.
///
/// Lifecycle hooks and test bodies can short-circuit by returning
/// `Error("message")` where the message is human-readable.
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
/// `SetupFailed` means the test body did not run because a lifecycle hook
/// failed first.
///
/// In Dream Test, hooks and test bodies can short-circuit with `Error("message")`.
/// When `before_all` fails, *all* tests in that suite become `SetupFailed`.
/// When `before_each` fails, only that test becomes `SetupFailed`.
///
/// ```gleam
/// import dream_test/unit.{before_all, describe, it}
/// import dream_test/types.{AssertionOk}
///
/// describe("Database", [
///   before_all(fn() { Error("could not connect to database") }),
///   it("test1", fn(_) { Ok(AssertionOk) }), // Never runs → SetupFailed
///   it("test2", fn(_) { Ok(AssertionOk) }), // Never runs → SetupFailed
/// ])
/// ```
///
/// The failing hook message is recorded on the `TestResult.failures` list so
/// reporters can display it.
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
/// Contains:
///
/// - the matcher/operator name (e.g. `"equal"` or `"be_ok"`)
/// - a user-friendly message (provided by `or_fail_with("...")`)
/// - optional structured payload for rich reporting
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
/// This is the value a test ultimately produces to indicate pass/fail/skip.
///
/// In typical usage, you don’t construct `AssertionResult` directly:
/// - assertion chains produce it
/// - `skip(...)` produces `AssertionSkipped`
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
/// let result: Result(AssertionResult, String) =
///   42
///   |> should()
///   |> equal(42)
///   |> or_fail_with("Should be 42")
/// // result == Ok(AssertionOk)
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
/// |> or_fail_with("expected Some(42)")  // -> Ok(AssertionOk)
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
/// import dream_test/types.{AssertionFailure, MatchFailed, MatchOk}
/// import gleam/option.{None}
///
/// pub fn be_even(result: MatchResult(Int)) -> MatchResult(Int) {
///   case result {
///     MatchFailed(failure) -> MatchFailed(failure)  // Propagate failure
///     MatchOk(value) -> check_is_even(value)        // Check the value
///   }
/// }
///
/// fn check_is_even(value: Int) -> MatchResult(Int) {
///   case value % 2 == 0 {
///     True -> MatchOk(value)
///     False ->
///       MatchFailed(AssertionFailure(
///         operator: "be_even",
///         message: "expected an even number",
///         payload: None,
///       ))
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
/// ## Parameters
///
/// - `result`: the `MatchResult(a)` you want to collapse into pass/fail
///
/// ## Returns
///
/// - `MatchOk(_)` becomes `AssertionOk`
/// - `MatchFailed(failure)` becomes `AssertionFailed(failure)`
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
/// After running suites, you get a list of these:
///
/// ```gleam
/// import dream_test/runner
/// import dream_test/unit.{describe, it}
/// import dream_test/types.{AssertionOk}
///
/// let suite =
///   describe("Example", [
///     it("passes", fn(_) { Ok(AssertionOk) }),
///   ])
///
/// let results = runner.new([suite]) |> runner.run()
/// // results: List(TestResult)
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

/// A single runnable test within a suite.
///
/// The test receives the suite context (possibly transformed by `before_each`)
/// and may short-circuit with an `Error("message")`.
///
/// This is the runnable “leaf node” that reporters ultimately display as a
/// `TestResult`.
///
/// You typically create these via the unit DSL (`unit.it`, `unit.skip`) or via
/// the Gherkin integration.
pub type SuiteTestCase(ctx) {
  SuiteTestCase(
    name: String,
    tags: List(String),
    kind: TestKind,
    run: fn(ctx) -> Result(AssertionResult, String),
    /// Optional per-test timeout override in milliseconds.
    /// If None, uses the runner's default timeout.
    timeout_ms: Option(Int),
  )
}

/// A structured test suite preserving group hierarchy.
///
/// Unlike a flat list of tests, a `TestSuite(ctx)` preserves the tree structure
/// of your `describe`/`group` blocks. This enables hook scoping and makes BDD
/// reporting possible (reporters can show nested names deterministically).
///
/// ## When will I touch this type?
///
/// Most users won’t construct `TestSuite` manually:
///
/// - `unit.describe(...)` returns a `TestSuite(Nil)`
/// - `unit.describe_with_hooks(...)` returns a `TestSuite(ctx)`
///
/// ## How It's Structured
///
/// ```text
/// TestSuite("Database tests")
/// ├── before_all: Some(start_db)
/// ├── items:
/// │   ├── SuiteTest("creates users")
/// │   ├── SuiteTest("queries users")
/// │   └── SuiteGroup(TestSuite("error cases"))
/// │       ├── before_all: None
/// │       ├── items:
/// │       │   ├── SuiteTest("handles not found")
/// │       │   └── SuiteTest("handles timeout")
/// │       └── after_all: []
/// └── after_all: [stop_db]
/// ```
///
/// ## Creating a TestSuite
///
/// Don't construct this directly. Use the unit DSL (`describe`, `group`, `it`,
/// etc.) to build it:
///
/// ```gleam
/// import dream_test/unit.{describe, it}
/// import dream_test/types.{AssertionOk}
///
/// pub fn tests() {
///   describe("My suite", [
///     it("works", fn(_) { Ok(AssertionOk) }),
///   ])
/// }
/// ```
///
/// ## Executing a TestSuite
///
/// Use the runner:
///
/// ```gleam
/// import dream_test/runner
/// runner.new([tests()]) |> runner.run()
/// ```
///
/// ## Fields (high level)
///
/// - `name`: this suite/group name
/// - `before_all`: optional root-only hook that produces the initial `ctx`
/// - `before_each` / `after_each`: per-test hooks scoped to this suite
/// - `after_all`: root-only cleanup hooks (failures stop subsequent suites)
/// - `items`: tests and nested groups
///
pub type TestSuite(ctx) {
  TestSuite(
    name: String,
    /// Runs once before any tests in this suite; produces the initial context.
    before_all: Option(fn() -> Result(ctx, String)),
    /// True only when the user explicitly provided a `before_all` hook.
    ///
    /// `unit.describe` injects an implicit `before_all` (Ok(Nil)) so root suites
    /// always run with a context, but we do not want reporters to display a
    /// lifecycle hook unless the user actually declared one.
    has_user_before_all: Bool,
    /// Runs once after all tests in this suite complete (even on failure).
    after_all: List(fn(ctx) -> Result(Nil, String)),
    /// Runs before each test (outer-to-inner); threads context for that test.
    before_each: List(fn(ctx) -> Result(ctx, String)),
    /// Runs after each test (inner-to-outer); always runs for cleanup.
    after_each: List(fn(ctx) -> Result(Nil, String)),
    items: List(TestSuiteItem(ctx)),
  )
}

/// An item within a test suite: either a single test or a nested group.
///
/// This type enables the recursive structure of `TestSuite`. You won't
/// typically construct these directly—they're created by the unit DSL.
///
/// ## Variants
///
/// - `SuiteTest(SuiteTestCase)` - A single test to execute
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
pub type TestSuiteItem(ctx) {
  /// A single test case to run.
  SuiteTest(SuiteTestCase(ctx))
  /// A nested group with its own hooks.
  SuiteGroup(TestSuite(ctx))
}

/// Derive a Status from a list of failures.
///
/// Returns `Passed` if there are no failures, `Failed` otherwise.
///
/// This helper is used when a test body (or hook) accumulates a list of
/// `AssertionFailure`s and needs to compute a summary status.
///
/// ## Parameters
///
/// - `failures`: assertion failures accumulated while running a test
///
/// ## Returns
///
/// - `Passed` when `failures` is empty
/// - `Failed` otherwise
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
