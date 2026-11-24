import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{type RunReport, type TestResult}
import dream_test/unit.{describe, it}
import gleam/list
import snippets/guides/writing_tests_cart
import snippets/guides/writing_tests_filter.{only_smoke, without_integration}

pub fn tests() {
  describe("The cart filters", [
    it("keep only the smoke test", fn() {
      // Act
      let report =
        runner.new([writing_tests_cart.tests()])
        |> runner.filter_tests(only_smoke)
        |> runner.silent()
        |> runner.run()

      // Assert
      test_names(report)
      |> should
      |> be_equal(["is 0 for an empty cart"])
      |> or_fail_with("only the smoke test should run")
    }),
    it("leave out the integration group", fn() {
      // Act
      let report =
        runner.new([writing_tests_cart.tests()])
        |> runner.filter_tests(without_integration)
        |> runner.silent()
        |> runner.run()

      // Assert
      test_names(report)
      |> should
      |> be_equal([
        "is 0 for an empty cart", "adds the prices",
        "takes 10% off above 100.00", "never goes below 0",
      ])
      |> or_fail_with("every test but the checkout test should run")
    }),
  ])
}

fn test_names(report: RunReport) -> List(String) {
  types.report_tests(report)
  |> list.map(test_name)
}

fn test_name(result: TestResult) -> String {
  result.name
}
