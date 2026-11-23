import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/suite.{type TestSuite}
import dream_test/types.{GherkinScenario, Passed, TestResult}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}

pub fn tests() -> TestSuite {
  describe("Gherkin scenario lines", [
    it("format_scenarios gives the lines without a summary", fn() {
      let result =
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

      gherkin_reporter.format_scenarios([result])
      |> should
      |> be_equal("Feature: Shopping Cart\n  Scenario: Adding items ✓\n")
      |> or_fail_with("expected one feature line and one scenario line")
    }),
  ])
}
