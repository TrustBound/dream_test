import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

fn example_tests() {
  describe("Example", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  runner.new([example_tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

pub fn tests() {
  describe("Exit status", [
    it("a run that passes returns its report", fn() { run_that_passes() }),
  ])
}

/// With `exit_on_failure`, a run that passes returns, and its report has
/// no failure.
fn run_that_passes() -> Result(AssertionResult, String) {
  runner.new([example_tests()])
  |> runner.silent()
  |> runner.exit_on_failure()
  |> runner.run()
  |> types.failed
  |> should
  |> be_equal(False)
  |> or_fail_with("a run that passes should return a report with no failure")
}
