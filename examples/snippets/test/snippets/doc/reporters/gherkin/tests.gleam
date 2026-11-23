import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport, AssertionOk}
import dream_test/unit.{describe, it}
import gleam/result
import snippets/doc/reporters/gherkin/format
import snippets/doc/reporters/gherkin/format_scenarios
import snippets/doc/reporters/gherkin/is_gherkin_result
import snippets_child_vm.{ChildRun, it_runs_in_child_vm}

fn run_silently(suite: TestSuite) -> RunReport {
  runner.new([suite])
  |> runner.silent()
  |> runner.run()
}

pub fn tests() -> TestSuite {
  describe("Doc examples: reporters/gherkin", [
    it("report_shows_the_feature_and_scenario passes", fn() {
      // Act
      let result = format.report_shows_the_feature_and_scenario()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected report_shows_the_feature_and_scenario to pass")
    }),
    it("the format_scenarios example suite passes", fn() {
      // Act
      let report = run_silently(format_scenarios.tests())

      // Assert
      types.failed(report)
      |> should
      |> be_equal(False)
      |> or_fail_with("expected the format_scenarios example to pass")
    }),
    it("scenario_is_a_gherkin_result passes", fn() {
      // Act
      let result = is_gherkin_result.scenario_is_a_gherkin_result()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected scenario_is_a_gherkin_result to pass")
    }),
    it_runs_in_child_vm("report main prints the Gherkin report", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/reporters/gherkin/report", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: "Shopping Cart\n"
            <> "  Scenario: adds items ✓\n"
            <> "\n"
            <> "Summary: 1 run, 0 failed, 1 passed in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with("expected the Gherkin report of the example suite")
    }),
  ])
}
