// ✅ No conflicts: unqualified from both
import dream_test/gherkin/types.{type Feature}
import dream_test/suite.{type TestSuite}

// Both Feature and TestSuite are unqualified

import dream_test/gherkin/steps
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types as test_types
import dream_test/unit.{describe, it}
import gleam/option.{None}

/// A suite with one group for the Feature, with no steps.
pub fn suite_of(feature: Feature) -> TestSuite {
  steps.to_suite(steps.new(Nil), "Shop", [], [steps.Feature(feature)])
}

pub fn tests() {
  describe("STANDARDS.md rule 7: no conflicting names", [
    it("makes a suite of a Feature with no scenarios", fn() {
      // Arrange
      let feature =
        types.Feature(
          name: "Shop",
          source: None,
          description: None,
          tags: [],
          background: None,
          scenarios: [],
          rules: [],
        )

      // Act
      let report =
        runner.new([suite_of(feature)]) |> runner.silent() |> runner.run()

      // Assert
      test_types.report_tests(report)
      |> should
      |> be_equal([])
      |> or_fail_with("a Feature with no scenarios should have no tests")
    }),
  ])
}
