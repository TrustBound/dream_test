import dream_test/coverage
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/option.{Some}

pub fn tests() {
  describe("Coverage badge", [
    it("uses the minimum that sets the badge colour", fn() {
      coverage_config()
      |> coverage.minimum()
      |> should
      |> be_equal(Some(80.0))
      |> or_fail_with("the minimum should be 80.0")
    }),
  ])
}

fn coverage_config() {
  coverage.new()
  |> coverage.json_path("build/coverage/coverage.json")
  |> coverage.minimum_percent(80.0)
}

pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.coverage(coverage_config())
  |> runner.exit_on_failure()
  |> runner.run()
}
