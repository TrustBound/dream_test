/// Core data types for the dream_test framework.
///
/// This module does not depend on the runner or assertion engine and can be
/// safely imported from most other layers.

import gleam/option.{type Option}

pub type Location {
  Location(
    module_: String,
    file: String,
    line: Int,
  )
}

pub type Status {
  Passed
  Failed
  Skipped
  Pending
  TimedOut
}

pub type TestKind {
  Unit
  Integration
  GherkinScenario(String)
}

pub type FailurePayload {
  EqualityFailure(
    actual: String,
    expected: String,
  )
}

pub type AssertionFailure {
  AssertionFailure(
    operator: String,
    message: String,
    location: Location,
    payload: Option(FailurePayload),
  )
}

/// Result of a single assertion chain.
///
/// This is internal to the assertion/runner plumbing; test authors just
/// pipe values through `should.equal` and `should.or_fail_with`.
pub type AssertionResult {
  AssertionOk
  AssertionFailed(AssertionFailure)
}

pub type ModuleCoverage {
  ModuleCoverage(
    module_: String,
    percent: Float,
    covered_lines: Int,
    total_lines: Int,
  )
}

pub type CoverageSummary {
  CoverageSummary(
    by_module: List(ModuleCoverage),
  )
}

pub type TestResult {
  TestResult(
    name: String,
    full_name: List(String),
    status: Status,
    duration_ms: Int,
    tags: List(String),
    failures: List(AssertionFailure),
    location: Location,
    kind: TestKind,
  )
}

/// Helper to derive a Status from a list of failures.
///
/// For now this is very simple: non-empty failures => Failed, otherwise Passed.
/// More nuanced states (e.g. Pending, Skipped) are handled by the runner.
pub fn status_from_failures(failures: List(AssertionFailure)) -> Status {
  case failures {
    [] -> Passed
    _ -> Failed
  }
}
