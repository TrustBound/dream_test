import dream_test/types.{type AssertionFailure}

/// Per-test context carrying assertion failures and any other
/// per-test metadata we may need later.
///
/// This is the core state threaded through assertions.
pub type TestContext {
  TestContext(
    failures: List(AssertionFailure),
  )
}

pub fn new() -> TestContext {
  TestContext(failures: [])
}

pub fn failures(context: TestContext) -> List(AssertionFailure) {
  context.failures
}

pub fn add_failure(context: TestContext, failure: AssertionFailure) -> TestContext {
  TestContext(failures: [failure, ..context.failures])
}
