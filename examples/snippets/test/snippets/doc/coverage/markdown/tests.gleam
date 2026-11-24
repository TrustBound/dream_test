import dream_test/coverage
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import snippets/doc/coverage/markdown/module
import snippets/doc/coverage/markdown/module_import_style
import snippets/doc/coverage/markdown/render

pub fn tests() {
  describe("Doc examples: coverage/markdown", [
    it("write_job_summary gives the documented result", fn() {
      // Act
      let result = module.write_job_summary("build/coverage/summary.md")

      // Assert
      result
      |> should
      |> be_equal(
        coverage.new() |> coverage.markdown_path("build/coverage/summary.md"),
      )
      |> or_fail_with(
        "expected write_job_summary to give the documented result",
      )
    }),
    it("empty_table gives the documented result", fn() {
      // Act
      let result = module_import_style.empty_table()

      // Assert
      result
      |> should
      |> be_equal(
        "## Coverage\n\n| File | Lines | Cover | Missing | Excluded |\n| --- | ---: | ---: | --- | --- |\n| Total | 0/0 | - |  |  |\n",
      )
      |> or_fail_with("expected empty_table to give the documented result")
    }),
    it("half_covered_table gives the documented result", fn() {
      // Act
      let result = render.half_covered_table()

      // Assert
      result
      |> should
      |> be_equal(
        "## Coverage\n\n| File | Lines | Cover | Missing | Excluded |\n| --- | ---: | ---: | --- | --- |\n| src/a.gleam | 1/2 | 50.0% | 2 |  |\n| Total | 1/2 | 50.0% |  |  |\n",
      )
      |> or_fail_with(
        "expected half_covered_table to give the documented result",
      )
    }),
  ])
}
