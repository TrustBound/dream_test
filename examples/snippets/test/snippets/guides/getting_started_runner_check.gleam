import dream_test/matchers.{be_equal, be_true, or_fail_with, should}
import dream_test/runner
import dream_test/types.{type RunReport, type TestResult}
import dream_test/unit.{describe, it}
import gleam/list
import snippets/guides/getting_started_failing_test.{failing_tests}

pub fn tests() {
  describe("The calculator tests", [
    it("fail the run when a test fails", fn() {
      // Act
      let report =
        runner.new([failing_tests()])
        |> runner.silent()
        |> runner.run()

      // Assert
      types.failed(report)
      |> should
      |> be_true()
      |> or_fail_with("a failing test should fail the run")
    }),
    it("report the failing test by its name", fn() {
      // Act
      let report =
        runner.new([failing_tests()])
        |> runner.silent()
        |> runner.run()

      // Assert
      failed_test_names(report)
      |> should
      |> be_equal(["rounds a division up"])
      |> or_fail_with("only the rounding test should fail")
    }),
  ])
}

fn failed_test_names(report: RunReport) -> List(String) {
  types.report_tests(report)
  |> list.filter(is_failed)
  |> list.map(test_name)
}

fn is_failed(result: TestResult) -> Bool {
  types.is_failure(result.status)
}

fn test_name(result: TestResult) -> String {
  result.name
}
