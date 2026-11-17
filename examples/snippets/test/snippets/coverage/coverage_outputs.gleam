import dream_test/coverage
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}

pub fn tests() {
  describe("Coverage output files", [
    it("writes LCOV to the chosen path", fn() {
      coverage_config()
      |> coverage.lcov_file()
      |> should
      |> be_equal(Some("build/coverage/app.info"))
      |> or_fail_with("the LCOV path should be build/coverage/app.info")
    }),
    it("writes no LCOV file with no_lcov", fn() {
      table_only_config()
      |> coverage.lcov_file()
      |> should
      |> be_equal(None)
      |> or_fail_with("no_lcov should turn LCOV off")
    }),
  ])
}

fn coverage_config() {
  coverage.new()
  |> coverage.lcov_path("build/coverage/app.info")
  |> coverage.json_path("build/coverage/coverage.json")
  |> coverage.cobertura_path("build/coverage/cobertura.xml")
  |> coverage.markdown_path("build/coverage/coverage.md")
  |> coverage.html_path("build/coverage/html")
  |> coverage.html_file("build/coverage/all.html")
}

fn table_only_config() {
  coverage.new()
  |> coverage.no_lcov()
}
