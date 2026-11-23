import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it, skip}

pub fn tests() -> TestSuite {
  describe("Skipping tests", [
    it("runs normally", fn() {
      2 + 3
      |> should
      |> be_equal(5)
      |> or_fail_with("2 + 3 should equal 5")
    }),
    skip("not implemented yet", fn() {
      // This test is skipped - the body is preserved but not executed
      100 + 200
      |> should
      |> be_equal(300)
      |> or_fail_with("Should add large numbers")
    }),
    it("also runs normally", fn() {
      0 + 0
      |> should
      |> be_equal(0)
      |> or_fail_with("0 + 0 should equal 0")
    }),
  ])
}

pub fn main() -> RunReport {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
