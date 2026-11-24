import dream_test/coverage
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/option.{Some}
import snippets/coverage/guide_coverage_first

pub fn main() {
  runner.new([guide_coverage_first.tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.coverage(coverage_config())
  |> runner.exit_on_failure()
  |> runner.run()
}

fn coverage_config() {
  coverage.new()
  |> coverage.source_directory("src/app")
  |> coverage.show_missing()
  |> coverage.minimum_percent(90.0)
}

pub fn tests() {
  describe("The coverage gate", [
    it("sets a minimum of 90%", fn() {
      // Act
      let minimum = coverage.minimum(coverage_config())

      // Assert
      minimum
      |> should
      |> be_equal(Some(90.0))
      |> or_fail_with("the minimum should be 90.0")
    }),
  ])
}
