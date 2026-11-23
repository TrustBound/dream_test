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

pub fn report_shows_the_feature_and_scenario() -> Result(
  AssertionResult,
  String,
) {
  gherkin_reporter.format(
    types.run_report(
      tests: [scenario_result()],
      hook_failures: [],
      reporter_crashes: [],
    ),
  )
  |> should
  |> be_equal(
    "Feature: Shopping Cart\n  Scenario: Adding items ✓\n\nSummary: 1 run, 0 failed, 1 passed in 0ms\n",
  )
  |> or_fail_with("expected the formatted report")
}
