//// The first test file of the getting started guide, with one more test
//// that fails. The guide shows the new test, and the report and the exit
//// status of `main`. The failing suite is `failing_tests`, so test
//// discovery runs only `tests`, which checks that the suite fails.

import dream_test/matchers.{be_equal, be_ok, be_true, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/types
import dream_test/unit.{describe, it}
import snippets.{add, divide}

pub fn failing_tests() {
  describe("Calculator", [
    it("adds two numbers", fn() {
      add(2, 3)
      |> should
      |> be_equal(5)
      |> or_fail_with("2 + 3 should be 5")
    }),
    it("divides two numbers", fn() {
      divide(10, 2)
      |> should
      |> be_ok()
      |> be_equal(5)
      |> or_fail_with("10 / 2 should be 5")
    }),
    it("rounds a division up", fn() {
      divide(7, 2)
      |> should
      |> be_ok()
      |> be_equal(4)
      |> or_fail_with("7 / 2 should round up to 4")
    }),
  ])
}

pub fn main() {
  runner.new([failing_tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

pub fn tests() {
  describe("The failing calculator suite", [
    it("fails the run", fn() {
      // Act
      let report =
        runner.new([failing_tests()])
        |> runner.silent()
        |> runner.run()

      // Assert
      types.failed(report)
      |> should
      |> be_true()
      |> or_fail_with("the rounding test should fail the run")
    }),
  ])
}
