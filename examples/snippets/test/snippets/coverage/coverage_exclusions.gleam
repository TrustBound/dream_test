import dream_test/coverage
import dream_test/matchers.{be_true, or_fail_with, should}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Coverage exclusions", [
    it("lists what is excluded", fn() {
      coverage_config()
      |> coverage.shows_excluded()
      |> should
      |> be_true()
      |> or_fail_with("show_excluded should be on")
    }),
  ])
}

fn coverage_config() {
  coverage.new()
  |> coverage.exclude("src/app/internal/**")
  |> coverage.exclude_with_reason("src/app/generated/**", "generated code")
  |> coverage.require_exclusion_reasons()
  |> coverage.show_excluded()
}
