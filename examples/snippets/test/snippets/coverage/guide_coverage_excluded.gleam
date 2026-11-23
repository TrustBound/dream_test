import dream_test/coverage
import dream_test/matchers.{be_true, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/unit.{describe, it}
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
  |> coverage.exclude_with_reason("src/app/generated/**", "generated code")
  |> coverage.exclude_with_reason("src/app/internal/**", "debug helpers")
  |> coverage.show_excluded()
  |> coverage.json_path("build/coverage/guide_coverage.json")
}

pub fn tests() {
  describe("The coverage gate with exclusions", [
    it("shows the excluded files", fn() {
      // Act
      let shows_excluded = coverage.shows_excluded(coverage_config())

      // Assert
      shows_excluded
      |> should
      |> be_true()
      |> or_fail_with("show_excluded should be on")
    }),
  ])
}
