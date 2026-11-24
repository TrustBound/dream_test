import dream_test/coverage
import dream_test/coverage/json_summary
import dream_test/coverage/report.{LineCoverage}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import snippets/doc/coverage/json_summary/minimum_percent
import snippets/doc/coverage/json_summary/minimum_percent_per_file
import snippets/doc/coverage/json_summary/module
import snippets/doc/coverage/json_summary/module_import_style
import snippets/doc/coverage/json_summary/options
import snippets/doc/coverage/json_summary/render

pub fn tests() {
  describe("Doc examples: coverage/json_summary", [
    it("write_json_summary gives the documented result", fn() {
      // Act
      let result = module.write_json_summary()

      // Assert
      result
      |> should
      |> be_equal(
        coverage.new() |> coverage.json_path("build/coverage/coverage.json"),
      )
      |> or_fail_with(
        "expected write_json_summary to give the documented result",
      )
    }),
    it("eighty_percent_minimum shows in the rendered JSON", fn() {
      // Arrange
      let options = module_import_style.eighty_percent_minimum()

      // Act
      let result = json_summary.render(report: report.new([]), options: options)

      // Assert
      result
      |> should
      |> be_equal(
        "{\"version\":1,\"files\":[],\"excluded_files\":[],\"total\":{\"lines_hit\":0,\"lines_total\":0,\"percent\":null},\"minimum_percent\":80.0,\"minimum_percent_per_file\":null}\n",
      )
      |> or_fail_with("expected eighty_percent_minimum in the JSON")
    }),
    it("render_without_minimums gives the documented result", fn() {
      // Act
      let result =
        options.render_without_minimums(
          report.new([
            report.file("src/a.gleam", [
              LineCoverage(line: 1, calls: 1),
              LineCoverage(line: 2, calls: 0),
            ]),
          ]),
        )

      // Assert
      result
      |> should
      |> be_equal(
        "{\"version\":1,\"files\":[{\"path\":\"src/a.gleam\",\"lines_hit\":1,\"lines_total\":2,\"percent\":50.0,\"missing\":[{\"first\":2,\"last\":2}],\"ignored\":[]}],\"excluded_files\":[],\"total\":{\"lines_hit\":1,\"lines_total\":2,\"percent\":50.0},\"minimum_percent\":null,\"minimum_percent_per_file\":null}\n",
      )
      |> or_fail_with(
        "expected render_without_minimums to give the documented result",
      )
    }),
    it("total_minimum_of_eighty shows in the rendered JSON", fn() {
      // Arrange
      let options = minimum_percent.total_minimum_of_eighty()

      // Act
      let result = json_summary.render(report: report.new([]), options: options)

      // Assert
      result
      |> should
      |> be_equal(
        "{\"version\":1,\"files\":[],\"excluded_files\":[],\"total\":{\"lines_hit\":0,\"lines_total\":0,\"percent\":null},\"minimum_percent\":80.0,\"minimum_percent_per_file\":null}\n",
      )
      |> or_fail_with("expected total_minimum_of_eighty in the JSON")
    }),
    it("file_minimum_of_fifty shows in the rendered JSON", fn() {
      // Arrange
      let options = minimum_percent_per_file.file_minimum_of_fifty()

      // Act
      let result = json_summary.render(report: report.new([]), options: options)

      // Assert
      result
      |> should
      |> be_equal(
        "{\"version\":1,\"files\":[],\"excluded_files\":[],\"total\":{\"lines_hit\":0,\"lines_total\":0,\"percent\":null},\"minimum_percent\":null,\"minimum_percent_per_file\":50.0}\n",
      )
      |> or_fail_with("expected file_minimum_of_fifty in the JSON")
    }),
    it("half_covered_json gives the documented result", fn() {
      // Act
      let result = render.half_covered_json()

      // Assert
      result
      |> should
      |> be_equal(
        "{\"version\":1,\"files\":[{\"path\":\"src/a.gleam\",\"lines_hit\":1,\"lines_total\":2,\"percent\":50.0,\"missing\":[{\"first\":2,\"last\":2}],\"ignored\":[]}],\"excluded_files\":[],\"total\":{\"lines_hit\":1,\"lines_total\":2,\"percent\":50.0},\"minimum_percent\":null,\"minimum_percent_per_file\":null}\n",
      )
      |> or_fail_with(
        "expected half_covered_json to give the documented result",
      )
    }),
  ])
}
