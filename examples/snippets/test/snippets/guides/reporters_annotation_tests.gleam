import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{
  AssertionFailure, Failed, Passed, TestResult, Unit, run_report,
}
import dream_test/unit.{describe, it}
import gleam/option.{None}
import snippets/guides/reporters_ci.{github_annotations}

pub fn tests() {
  describe("github_annotations", [
    it("writes one error line for a failed test", fn() {
      // Arrange
      let failed =
        TestResult(
          name: "adds the tax",
          groups: ["Checkout"],
          status: Failed,
          duration_ms: 3,
          tags: [],
          failures: [
            AssertionFailure(
              operator: "be_equal",
              message: "tax should be 20%",
              payload: None,
            ),
          ],
          kind: Unit,
        )
      let report =
        run_report(tests: [failed], hook_failures: [], reporter_crashes: [])

      // Act
      let text = github_annotations(report)

      // Assert
      text
      |> should
      |> be_equal("::error title=Checkout > adds the tax::tax should be 20%\n")
      |> or_fail_with("a failed test should give one annotation line")
    }),
    it("writes nothing for a run that passed", fn() {
      // Arrange
      let passed =
        TestResult(
          name: "totals the cart",
          groups: ["Checkout"],
          status: Passed,
          duration_ms: 1,
          tags: [],
          failures: [],
          kind: Unit,
        )
      let report =
        run_report(tests: [passed], hook_failures: [], reporter_crashes: [])

      // Act
      let text = github_annotations(report)

      // Assert
      text
      |> should
      |> be_equal("")
      |> or_fail_with("a run that passed should give no annotation")
    }),
  ])
}
