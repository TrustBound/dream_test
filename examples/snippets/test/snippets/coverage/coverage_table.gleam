import dream_test/coverage
import dream_test/matchers.{be_true, or_fail_with, should}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Coverage table options", [
    it("prints in colour", fn() {
      coverage_config()
      |> coverage.uses_color()
      |> should
      |> be_true()
      |> or_fail_with("color should be on")
    }),
    it("lists the lowest coverage first", fn() {
      coverage_config()
      |> coverage.sorts_by_coverage()
      |> should
      |> be_true()
      |> or_fail_with("sort_by_coverage should be on")
    }),
    it("hides complete files", fn() {
      coverage_config()
      |> coverage.hides_complete()
      |> should
      |> be_true()
      |> or_fail_with("hide_complete should be on")
    }),
  ])
}

fn coverage_config() {
  coverage.new()
  |> coverage.show_missing()
  |> coverage.color()
  |> coverage.sort_by_coverage()
  |> coverage.hide_complete()
}
