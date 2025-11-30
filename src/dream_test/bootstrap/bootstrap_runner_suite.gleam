import dream_test/assertions/context.{type TestContext, add_failure}
import dream_test/bootstrap/core_assert
import dream_test/core/types.{AssertionFailure, Location, Unit, Passed, Failed}
import dream_test/runner.{type TestCase, TestCase, SingleTestConfig, run_all}

fn passing_test(test_context: TestContext(Int)) -> TestContext(Int) {
  test_context
}

fn failing_test(test_context: TestContext(Int)) -> TestContext(Int) {
  let failure = AssertionFailure(
    actual: 1,
    expected: 2,
    operator: "equal",
    message: "",
    location: Location("bootstrap_runner_suite", "bootstrap_runner_suite.gleam", 0),
  )

  add_failure(test_context, failure)
}

/// Bootstrap checks for running a small suite of tests.
///
/// Verifies that run_all returns results in order and with correct statuses.
pub fn main() {
  let common_full_name = ["bootstrap", "runner_suite"]
  let common_tags = ["bootstrap", "runner"]
  let common_location = Location("bootstrap_runner_suite", "bootstrap_runner_suite.gleam", 0)

  let passing_config = SingleTestConfig(
    name: "passing test",
    full_name: common_full_name,
    tags: common_tags,
    kind: Unit,
    location: common_location,
    run: passing_test,
  )

  let failing_config = SingleTestConfig(
    name: "failing test",
    full_name: common_full_name,
    tags: common_tags,
    kind: Unit,
    location: common_location,
    run: failing_test,
  )

  let test_cases: List(TestCase(Int)) = [
    TestCase(passing_config),
    TestCase(failing_config),
  ]

  let results = run_all(test_cases)

  // Expect two results in the same order as the input test cases.
  case results {
    [first, second] -> {
      core_assert.equal("passing test", first.name, "First test name should match")
      core_assert.equal(Passed, first.status, "First test should be Passed")

      core_assert.equal("failing test", second.name, "Second test name should match")
      core_assert.equal(Failed, second.status, "Second test should be Failed")
    }

    _ ->
      core_assert.is_true(False, "Expected exactly two results from run_all")
  }
}
