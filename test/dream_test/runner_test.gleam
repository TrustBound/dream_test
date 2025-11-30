import dream_test/bootstrap/assertions
import gleam/option.{Some}
import dream_test/types.{type AssertionResult, AssertionFailure, AssertionOk, AssertionFailed, EqualityFailure, Location, Unit, Passed, Failed}
import dream_test/runner.{SingleTestConfig, run_single_test}

fn passing_test() -> AssertionResult {
  AssertionOk
}

fn failing_test() -> AssertionResult {
  let failure = AssertionFailure(
    operator: "equal",
    message: "",
    location: Location("bootstrap_runner_core", "bootstrap_runner_core.gleam", 0),
    payload: Some(EqualityFailure(
      actual: "1",
      expected: "2",
    )),
  )

  AssertionFailed(failure)
}

/// Bootstrap checks for the minimal runner core.
///
/// Verifies that a passing test produces a Passed status with no failures,
/// and a failing test produces a Failed status with at least one failure.
pub fn main() {
  let common_full_name = ["bootstrap", "runner_core"]
  let common_tags = ["bootstrap", "runner"]
  let common_location = Location("bootstrap_runner_core", "bootstrap_runner_core.gleam", 0)

  let passing_config = SingleTestConfig(
    name: "passing test",
    full_name: common_full_name,
    tags: common_tags,
    kind: Unit,
    location: common_location,
    run: passing_test,
  )

  let passing_result = run_single_test(passing_config)

  assertions.equal(Passed, passing_result.status, "Passing test should have Passed status")
  assertions.equal([], passing_result.failures, "Passing test should have no failures")

  let failing_config = SingleTestConfig(
    name: "failing test",
    full_name: common_full_name,
    tags: common_tags,
    kind: Unit,
    location: common_location,
    run: failing_test,
  )

  let failing_result = run_single_test(failing_config)

  assertions.equal(Failed, failing_result.status, "Failing test should have Failed status")

  case failing_result.failures {
    [] ->
      assertions.is_true(False, "Failing test should have at least one failure")
    [_, .._] ->
      assertions.is_true(True, "Failing test recorded at least one failure")
  }
}
