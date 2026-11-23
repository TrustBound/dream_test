import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/types.{
  type AssertionResult, type TestResult, GherkinScenario, Passed, TestResult,
}
import gleam/option.{None, Some}

pub fn scenario_result() -> TestResult {
  TestResult(
    name: "Adding items",
    groups: ["Shopping Cart"],
    status: Passed,
    duration_ms: 0,
    tags: [],
    failures: [],
    kind: GherkinScenario(
      scenario_id: "cart",
      feature: Some("Shopping Cart"),
      rule: None,
    ),
  )
}

pub fn scenario_is_a_gherkin_result() -> Result(AssertionResult, String) {
  gherkin_reporter.is_gherkin_result(scenario_result())
  |> should
  |> be_equal(True)
  |> or_fail_with("expected True for gherkin results")
}
