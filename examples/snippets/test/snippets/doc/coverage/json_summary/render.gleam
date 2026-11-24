import dream_test/coverage/json_summary
import dream_test/coverage/report.{LineCoverage}

pub fn half_covered_json() -> String {
  report.new([
    report.file("src/a.gleam", [
      LineCoverage(line: 1, calls: 1),
      LineCoverage(line: 2, calls: 0),
    ]),
  ])
  |> json_summary.render(options: json_summary.options())
  // -> "{\"version\":1,\"files\":[{\"path\":\"src/a.gleam\",\"lines_hit\":1,\"lines_total\":2,\"percent\":50.0,\"missing\":[{\"first\":2,\"last\":2}],\"ignored\":[]}],\"excluded_files\":[],\"total\":{\"lines_hit\":1,\"lines_total\":2,\"percent\":50.0},\"minimum_percent\":null,\"minimum_percent_per_file\":null}\n"
}
