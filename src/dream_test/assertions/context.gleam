import dream_test/core/types.{type AssertionFailure}

/// Per-test context carrying assertion failures and any other
/// per-test metadata we may need later.
///
/// This is the core state threaded through assertions.
pub type TestContext(a) {
  TestContext(
    failures: List(AssertionFailure(a)),
  )
}

pub fn new() -> TestContext(a) {
  TestContext(failures: [])
}

pub fn failures(context: TestContext(a)) -> List(AssertionFailure(a)) {
  context.failures
}

pub fn add_failure(context: TestContext(a), failure: AssertionFailure(a)) -> TestContext(a) {
  TestContext(failures: [failure, ..context.failures])
}
