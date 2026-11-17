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
