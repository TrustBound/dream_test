import dream_test/coverage
import dream_test/matchers.{be_true, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Coverage from the environment", [
    it("shows the missing lines when coverage is on", fn() {
      coverage_config()
      |> coverage.shows_missing()
      |> should
      |> be_true()
      |> or_fail_with("show_missing should be on")
    }),
  ])
}

fn coverage_config() {
  coverage.new()
  |> coverage.show_missing()
}

pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.coverage_from_environment(coverage_config())
  |> runner.exit_on_failure()
  |> runner.run()
}
