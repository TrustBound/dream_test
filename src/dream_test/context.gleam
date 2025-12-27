//// Per-test context.
////
//// This module provides a small record (`TestContext`) for storing
//// `types.AssertionFailure` values. Most test code won’t interact with it
//// directly—matchers already turn failures into `types.AssertionResult`.
////
//// You may find it useful if you’re building custom integrations where you want
//// to accumulate multiple failures during a single test run.

import dream_test/types.{type AssertionFailure}

/// Per-test context carrying assertion failures and any other
/// per-test metadata we may need later.
///
/// Most users do not need this type. Dream Test’s public matcher pipeline
/// (`should |> ...`) carries failures via `types.MatchResult`, and the runner
/// reports failures via `types.TestResult`.
///
/// `TestContext` exists as a small, explicit record for internal bookkeeping
/// and future extension (e.g. if the framework needs to accumulate multiple
/// failures during a single test run).
///
/// ## Example
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{AssertionFailure}
/// import dream_test/unit.{describe, it}
/// import gleam/option.{None}
///
/// pub fn tests() {
///   describe("dream_test/context", [
///     it("new has no failures", fn() {
///       context.new()
///       |> context.failures()
///       |> should
///       |> be_equal([])
///       |> or_fail_with("expected new context to have no failures")
///     }),
///
///     it("add_failure stores failures newest-first", fn() {
///       let first_failure =
///         AssertionFailure(operator: "op1", message: "m1", payload: None)
///       let second_failure =
///         AssertionFailure(operator: "op2", message: "m2", payload: None)
///
///       context.new()
///       |> context.add_failure(first_failure)
///       |> context.add_failure(second_failure)
///       |> context.failures()
///       |> should
///       |> be_equal([second_failure, first_failure])
///       |> or_fail_with("expected newest-first failure ordering")
///     }),
///   ])
/// }
/// ```
///
/// ## Fields
///
/// - `failures`: stored newest-first
pub type TestContext {
  TestContext(failures: List(AssertionFailure))
}

/// Create a new, empty `TestContext`.
///
/// ## Returns
///
/// A `TestContext` with no recorded failures.
///
/// ## Parameters
///
/// None.
///
/// ## Example
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{AssertionFailure}
/// import dream_test/unit.{describe, it}
/// import gleam/option.{None}
///
/// pub fn tests() {
///   describe("dream_test/context", [
///     it("new has no failures", fn() {
///       context.new()
///       |> context.failures()
///       |> should
///       |> be_equal([])
///       |> or_fail_with("expected new context to have no failures")
///     }),
///
///     it("add_failure stores failures newest-first", fn() {
///       let first_failure =
///         AssertionFailure(operator: "op1", message: "m1", payload: None)
///       let second_failure =
///         AssertionFailure(operator: "op2", message: "m2", payload: None)
///
///       context.new()
///       |> context.add_failure(first_failure)
///       |> context.add_failure(second_failure)
///       |> context.failures()
///       |> should
///       |> be_equal([second_failure, first_failure])
///       |> or_fail_with("expected newest-first failure ordering")
///     }),
///   ])
/// }
/// ```
pub fn new() -> TestContext {
  TestContext(failures: [])
}

/// Get all failures recorded in a `TestContext`.
///
/// Failures are stored newest-first.
///
/// ## Parameters
///
/// - `context`: the `TestContext` to inspect
///
/// ## Example
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{AssertionFailure}
/// import dream_test/unit.{describe, it}
/// import gleam/option.{None}
///
/// pub fn tests() {
///   describe("dream_test/context", [
///     it("new has no failures", fn() {
///       context.new()
///       |> context.failures()
///       |> should
///       |> be_equal([])
///       |> or_fail_with("expected new context to have no failures")
///     }),
///
///     it("add_failure stores failures newest-first", fn() {
///       let first_failure =
///         AssertionFailure(operator: "op1", message: "m1", payload: None)
///       let second_failure =
///         AssertionFailure(operator: "op2", message: "m2", payload: None)
///
///       context.new()
///       |> context.add_failure(first_failure)
///       |> context.add_failure(second_failure)
///       |> context.failures()
///       |> should
///       |> be_equal([second_failure, first_failure])
///       |> or_fail_with("expected newest-first failure ordering")
///     }),
///   ])
/// }
/// ```
///
/// ## Returns
///
/// A list of `AssertionFailure` values (newest-first).
pub fn failures(context context: TestContext) -> List(AssertionFailure) {
  context.failures
}

/// Record an `AssertionFailure` in a `TestContext`.
///
/// Dream Test represents assertion failures as structured values
/// (`types.AssertionFailure`). This helper lets internal code accumulate those
/// failures while a test runs.
///
/// Failures are stored **newest-first**, so adding a failure is \(O(1)\).
///
/// ## Parameters
///
/// - `context`: the current `TestContext`
/// - `failure`: the failure to record
///
/// ## Returns
///
/// A new `TestContext` containing the added failure.
///
/// ## Example
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{AssertionFailure}
/// import dream_test/unit.{describe, it}
/// import gleam/option.{None}
///
/// pub fn tests() {
///   describe("dream_test/context", [
///     it("new has no failures", fn() {
///       context.new()
///       |> context.failures()
///       |> should
///       |> be_equal([])
///       |> or_fail_with("expected new context to have no failures")
///     }),
///
///     it("add_failure stores failures newest-first", fn() {
///       let first_failure =
///         AssertionFailure(operator: "op1", message: "m1", payload: None)
///       let second_failure =
///         AssertionFailure(operator: "op2", message: "m2", payload: None)
///
///       context.new()
///       |> context.add_failure(first_failure)
///       |> context.add_failure(second_failure)
///       |> context.failures()
///       |> should
///       |> be_equal([second_failure, first_failure])
///       |> or_fail_with("expected newest-first failure ordering")
///     }),
///   ])
/// }
/// ```
pub fn add_failure(
  context context: TestContext,
  failure failure: AssertionFailure,
) -> TestContext {
  TestContext(failures: [failure, ..context.failures])
}
