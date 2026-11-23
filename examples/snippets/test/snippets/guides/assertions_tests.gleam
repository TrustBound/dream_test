//// The tests of the outputs that the guide on matchers shows.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/guides/assertions_failure_reasons
import snippets/guides/assertions_failures
import snippets_outputs

pub fn tests() -> TestSuite {
  describe("Guide: matchers", [
    it("the failures report shows each kind of failure", fn() {
      // Act
      let report =
        runner.new([assertions_failures.failing_tests()])
        |> runner.silent()
        |> runner.run()
        |> snippets_outputs.render_with_bdd(reporter_types.BddFailuresOnly)

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_assertions_failures"))
      |> or_fail_with("expected test/outputs/guide_assertions_failures.txt")
    }),
    it("the failure reasons check passes", fn() {
      // Act
      let report =
        snippets_outputs.bdd_report([assertions_failure_reasons.tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_assertions_reasons"))
      |> or_fail_with("expected test/outputs/guide_assertions_reasons.txt")
    }),
  ])
}
