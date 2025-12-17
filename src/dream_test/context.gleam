import dream_test/types.{type AssertionFailure}

/// Per-test context carrying assertion failures and any other
/// per-test metadata we may need later.
///
/// Most users do not need this type. Dream Test’s public matcher pipeline
/// (`should() |> ...`) carries failures via `types.MatchResult`, and the runner
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
/// import dream_test/context
///
/// let ctx = context.new()
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
///
/// let all = context.failures(ctx)
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
/// import dream_test/context
/// import dream_test/types.{AssertionFailure}
///
/// let ctx0 = context.new()
/// let failure = AssertionFailure(operator: "equal", message: "nope", payload: None)
/// let ctx1 = context.add_failure(ctx0, failure)
/// ```
pub fn add_failure(
  context: TestContext,
  failure: AssertionFailure,
) -> TestContext {
  TestContext(failures: [failure, ..context.failures])
}
