//// Test fixtures for creating TestResult instances.

import dream_test/types.{type Status, type TestResult, TestResult, Unit}

/// Create a simple test result with the given name and status.
pub fn make_test(name: String, status: Status) -> TestResult {
  TestResult(
    name: name,
    groups: [],
    status: status,
    duration_ms: 0,
    tags: [],
    failures: [],
    kind: Unit,
  )
}

/// Create a test result with a specific duration.
pub fn make_test_with_duration(
  name: String,
  status: Status,
  duration_ms: Int,
) -> TestResult {
  TestResult(
    name: name,
    groups: [],
    status: status,
    duration_ms: duration_ms,
    tags: [],
    failures: [],
    kind: Unit,
  )
}

/// A run report with these test results and no tear-down failures.
pub fn report_of(results: List(TestResult)) -> types.RunReport {
  types.run_report(tests: results, teardown_failures: [], reporter_crashes: [])
}

/// A tear-down failure of `after_all` in the group `root`.
pub fn cleanup_failure() -> types.TeardownFailure {
  types.TeardownFailure(
    hook: types.AfterAllHook,
    groups: ["root"],
    message: "no cleanup",
  )
}

/// A run report with these test results and the tear-down failure of
/// `cleanup_failure`.
pub fn report_with_cleanup_failure(
  results: List(TestResult),
) -> types.RunReport {
  types.run_report(
    tests: results,
    teardown_failures: [cleanup_failure()],
    reporter_crashes: [],
  )
}
