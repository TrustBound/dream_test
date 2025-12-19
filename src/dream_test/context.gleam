//// Per-test context bookkeeping.
////
//// Most users should not need this module directly; it exists to support
//// internal plumbing and future extensibility.

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
pub type TestContext {
  TestContext(failures: List(AssertionFailure))
}

/// Create a new, empty `TestContext`.
///
/// ## Returns
///
/// A `TestContext` with no recorded failures.
///
/// ## Example
///
/// ```gleam
/// // examples/snippets/test/snippets/utils/context_helpers.gleam
/// import dream_test/context
///
/// let failures = context.new() |> context.failures()
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
/// // examples/snippets/test/snippets/utils/context_helpers.gleam
/// import dream_test/context
///
/// let all = context.new() |> context.failures()
/// ```
///
/// ## Returns
///
/// A list of `AssertionFailure` values (newest-first).
pub fn failures(context: TestContext) -> List(AssertionFailure) {
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
/// // examples/snippets/test/snippets/utils/context_helpers.gleam
/// import dream_test/context
/// import dream_test/types.{AssertionFailure}
/// import gleam/option.{None}
///
/// let f1 = AssertionFailure(operator: "op1", message: "m1", payload: None)
/// let f2 = AssertionFailure(operator: "op2", message: "m2", payload: None)
///
/// let failures =
///   context.new()
///   |> context.add_failure(f1)
///   |> context.add_failure(f2)
///   |> context.failures()
/// // failures == [f2, f1]
/// ```
pub fn add_failure(
  context: TestContext,
  failure: AssertionFailure,
) -> TestContext {
  TestContext(failures: [failure, ..context.failures])
}
