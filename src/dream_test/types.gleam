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
//// pub fn be_even(result) {
////   case result {
////     // If already failed, propagate the failure
////     MatchFailed(failure) -> MatchFailed(failure)
////     // Otherwise, check our condition
////     MatchOk(value) -> check_even(value)
////   }
//// }
////
//// fn check_even(value) {
////   case value % 2 == 0 {
////     True -> MatchOk(value)
////     False ->
////       MatchFailed(AssertionFailure(
////         operator: "be_even",
////         message: "",
////         payload: Some(CustomMatcherFailure(
////           actual: int.to_string(value),
////           description: "expected an even number",
////         )),
////       ))
////   }
//// }
//// ```
//// =============================================================================
//// Unified tree model (Root/Node)
//// =============================================================================
////
//// Dream Test compiles all unit/context/gherkin tests into a single tree model
//// that the executor runs.
////
//// - `Root(context)` holds the initial seed value and a single root `Node`.
//// - `Node(context)` represents groups, tests, and lifecycle hooks.
////

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
/// describe("Handles failures", [
///   before_all(fn() {
///     case connect_to_database() {
///       Ok(_) -> Ok(Nil)
///       Error(e) -> Error("Database connection failed: " <> e)
///     }
///   }),
///   // If before_all fails, these tests are marked SetupFailed (not run)
///   it("test1", fn() { Ok(succeed()) }),
///   it("test2", fn() { Ok(succeed()) }),
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
/// 2 + 3
/// |> should
/// |> be_equal(5)
/// |> or_fail_with("2 + 3 should equal 5")
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
/// Some(42)
/// |> should
/// |> be_some()
/// |> be_equal(42)
/// |> or_fail_with("expected Some(42)")
/// ```
///
/// If any matcher fails, the `MatchFailed` propagates through the rest of
/// the chain without executing further checks.
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
/// types.to_assertion_result(types.MatchOk(1))
/// |> should
/// |> be_equal(types.AssertionOk)
/// |> or_fail_with("expected MatchOk -> AssertionOk")
/// ```
///
pub fn to_assertion_result(result result: MatchResult(a)) -> AssertionResult {
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
/// let results = runner.new([example_suite()]) |> runner.run()
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

/// A complete test suite in the unified execution model.
///
/// A `Root(context)` stores the initial `seed` context value and the top-level
/// `tree` (`Node(context)`) containing groups, tests, and hooks.
pub type Root(context) {
  Root(seed: context, tree: Node(context))
}

/// A node in the unified test tree: groups, tests, and hooks.
///
/// Most users build these values via `dream_test/unit` or `dream_test/unit_context`.
pub type Node(context) {
  /// A named group containing child nodes.
  Group(name: String, tags: List(String), children: List(Node(context)))

  /// A runnable test leaf.
  Test(
    name: String,
    tags: List(String),
    kind: TestKind,
    run: fn(context) -> Result(AssertionResult, String),
    timeout_ms: Option(Int),
  )

  /// Group-scoped hooks.
  BeforeAll(run: fn(context) -> Result(context, String))
  BeforeEach(run: fn(context) -> Result(context, String))
  AfterEach(run: fn(context) -> Result(Nil, String))
  AfterAll(run: fn(context) -> Result(Nil, String))
}

/// Compatibility alias: suites are roots in the unified model.
pub type TestSuite(context) =
  Root(context)

/// Compatibility alias: suite items are nodes in the unified model.
pub type TestSuiteItem(context) =
  Node(context)

/// Construct a root suite with a single top-level group.
///
/// This is primarily a low-level helper; most users should start from
/// `dream_test/unit.describe` or `dream_test/unit_context.describe`.
///
/// ## Parameters
///
/// - `name`: name of the top-level group
/// - `seed`: the initial context value stored in the `Root`
/// - `children`: children under the top-level group
///
/// ## Returns
///
/// A `Root(context)` containing a `Group(name: name, ...)` at the top.
pub fn root(
  name name: String,
  seed seed: context,
  children children: List(Node(context)),
) -> Root(context) {
  Root(seed: seed, tree: Group(name: name, tags: [], children: children))
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
/// types.status_from_failures([])
/// |> should
/// |> be_equal(types.Passed)
/// |> or_fail_with("expected Passed for empty failures")
/// ```
///
pub fn status_from_failures(failures failures: List(AssertionFailure)) -> Status {
  case failures {
    [] -> Passed
    _ -> Failed
  }
}
