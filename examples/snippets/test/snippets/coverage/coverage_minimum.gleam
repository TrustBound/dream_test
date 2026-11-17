import dream_test/coverage
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{Some}

pub fn tests() {
  describe("Coverage minimum", [
    it("keeps the total minimum", fn() {
      coverage_config()
      |> coverage.minimum()
      |> should
      |> be_equal(Some(80.0))
      |> or_fail_with("the total minimum should be 80.0")
    }),
    it("keeps the per-file minimum", fn() {
      coverage_config()
      |> coverage.minimum_per_file()
      |> should
      |> be_equal(Some(60.0))
      |> or_fail_with("the per-file minimum should be 60.0")
    }),
  ])
}

fn coverage_config() {
  coverage.new()
  |> coverage.minimum_percent(80.0)
  |> coverage.minimum_percent_per_file(60.0)
}
