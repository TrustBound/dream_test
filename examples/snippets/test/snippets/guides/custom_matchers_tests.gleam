//// The tests of the outputs that the guide on custom matchers shows.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/guides/custom_matchers_matcher_tests
import snippets/guides/custom_matchers_usage
import snippets_outputs

pub fn tests() -> TestSuite {
  describe("Guide: custom matchers", [
    it("the failure report shows the custom failure", fn() {
      // Act
      let report =
        snippets_outputs.bdd_report([custom_matchers_usage.failing_tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_custom_matchers_failure"))
      |> or_fail_with("expected test/outputs/guide_custom_matchers_failure.txt")
    }),
    it("the matcher tests pass", fn() {
      // Act
      let report =
        snippets_outputs.bdd_report([custom_matchers_matcher_tests.tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_custom_matchers_checks"))
      |> or_fail_with("expected test/outputs/guide_custom_matchers_checks.txt")
    }),
  ])
}
