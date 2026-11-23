//// The tests of the outputs that the guide on Gherkin shows.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/guides/gherkin_cart_steps
import snippets/guides/gherkin_file_failures
import snippets/guides/gherkin_step_tests
import snippets/readme/gherkin_inline
import snippets_outputs

/// The Gherkin report of a run of `suites`, with every duration set to 0.
fn gherkin_report(suites: List(TestSuite)) -> String {
  runner.new(suites)
  |> runner.silent()
  |> runner.run()
  |> snippets_outputs.without_durations()
  |> gherkin_reporter.format()
}

pub fn tests() -> TestSuite {
  describe("Guide: Gherkin", [
    it("the inline feature passes", fn() {
      // Act
      let report = gherkin_report([gherkin_inline.tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_gherkin_inline"))
      |> or_fail_with("expected test/outputs/guide_gherkin_inline.txt")
    }),
    it("a failing check and an undefined step fail their scenarios", fn() {
      // Act
      let report = gherkin_report([gherkin_cart_steps.failing_feature()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_gherkin_failures"))
      |> or_fail_with("expected test/outputs/guide_gherkin_failures.txt")
    }),
    it("each failure of a feature file names its step and line", fn() {
      // Act
      let report =
        gherkin_report([gherkin_file_failures.failing_feature_file()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_gherkin_file_failures"))
      |> or_fail_with("expected test/outputs/guide_gherkin_file_failures.txt")
    }),
    it("the step tests pass", fn() {
      // Act
      let report = snippets_outputs.bdd_report([gherkin_step_tests.tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_gherkin_check"))
      |> or_fail_with("expected test/outputs/guide_gherkin_check.txt")
    }),
  ])
}
