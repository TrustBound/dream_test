import dream_test/assertions/context.{type TestContext, add_failure}
import dream_test/bootstrap/core_assert
import dream_test/core/types.{AssertionFailure, Location, Unit, Passed, Failed}
import dream_test/runner.{SingleTestConfig, run_single_test}

fn passing_test(test_context: TestContext(Int)) -> TestContext(Int) {
  test_context
}

fn failing_test(test_context: TestContext(Int)) -> TestContext(Int) {
  let failure = AssertionFailure(
    actual: 1,
    expected: 2,
    operator: "equal",
    message: "",
    location: Location("bootstrap_runner_core", "bootstrap_runner_core.gleam", 0),
  )

  add_failure(test_context, failure)
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

  core_assert.equal(Passed, passing_result.status, "Passing test should have Passed status")
  core_assert.equal([], passing_result.failures, "Passing test should have no failures")

  let failing_config = SingleTestConfig(
    name: "failing test",
    full_name: common_full_name,
    tags: common_tags,
    kind: Unit,
    location: common_location,
    run: failing_test,
  )

  let failing_result = run_single_test(failing_config)

  core_assert.equal(Failed, failing_result.status, "Failing test should have Failed status")

  case failing_result.failures {
    [] ->
      core_assert.is_true(False, "Failing test should have at least one failure")
    [_, .._] ->
      core_assert.is_true(True, "Failing test recorded at least one failure")
  }
}
