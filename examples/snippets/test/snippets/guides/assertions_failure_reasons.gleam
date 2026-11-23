import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{type AssertionFailure, type RunReport, type TestResult}
import dream_test/unit.{describe, it}
import gleam/list
import snippets/guides/assertions_failures.{failing_tests}

pub fn tests() {
  describe("The failure examples", [
    it("each fail at the matcher that the test name says", fn() {
      // Act
      let report =
        runner.new([failing_tests()])
        |> runner.silent()
        |> runner.run()

      // Assert
      failed_operators(report)
      |> should
      |> be_equal([
        #("a different value", ["be_equal"]),
        #("an Error where an Ok was expected", ["be_ok"]),
        #("a None where a Some was expected", ["be_some"]),
        #("a missing item", ["contain"]),
        #("a string with another start", ["start_with"]),
        #("a failure from your own logic", ["fail_with"]),
        #("an Error from the test body", ["error"]),
      ])
      |> or_fail_with("each test should fail at its own matcher")
    }),
  ])
}

/// The name of each test, with the operator of each of its failures.
fn failed_operators(report: RunReport) -> List(#(String, List(String))) {
  types.report_tests(report)
  |> list.map(name_and_operators)
}

fn name_and_operators(result: TestResult) -> #(String, List(String)) {
  #(result.name, list.map(result.failures, operator))
}

fn operator(failure: AssertionFailure) -> String {
  failure.operator
}
