import dream_test/coverage/json_summary
import dream_test/coverage/report.{LineCoverage}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}
import gleam/string

fn full_report() {
  report.new([
    report.file("src/app/cart.gleam", [
      LineCoverage(line: 3, calls: 2),
      LineCoverage(line: 4, calls: 0),
      LineCoverage(line: 5, calls: 0),
      LineCoverage(line: 9, calls: 1),
    ])
      |> report.add_ignored_ranges([
        report.ignored_range(
          first_line: 40,
          last_line: 44,
          reason: Some("debug \"only\""),
        ),
        report.ignored_range(first_line: 71, last_line: 71, reason: None),
      ]),
    report.file("src/app/types.gleam", []),
  ])
  |> report.add_excluded_files([
    report.excluded_file(
      source_path: "src/app/generated/db.gleam",
      pattern: "src/app/generated/**",
      reason: Some("generated code"),
    ),
    report.excluded_file(
      source_path: "src/app_ffi.erl",
      pattern: "src/*_ffi.erl",
      reason: None,
    ),
  ])
}

fn full_json() {
  string.concat([
    "{\"version\":1,\"files\":[",
    "{\"path\":\"src/app/cart.gleam\",\"lines_hit\":2,\"lines_total\":4,\"percent\":50.0,",
    "\"missing\":[{\"first\":4,\"last\":5}],",
    "\"ignored\":[{\"first\":40,\"last\":44,\"reason\":\"debug \\\"only\\\"\"},{\"first\":71,\"last\":71,\"reason\":null}]},",
    "{\"path\":\"src/app/types.gleam\",\"lines_hit\":0,\"lines_total\":0,\"percent\":null,\"missing\":[],\"ignored\":[]}],",
    "\"excluded_files\":[",
    "{\"path\":\"src/app/generated/db.gleam\",\"pattern\":\"src/app/generated/**\",\"reason\":\"generated code\"},",
    "{\"path\":\"src/app_ffi.erl\",\"pattern\":\"src/*_ffi.erl\",\"reason\":null}],",
    "\"total\":{\"lines_hit\":2,\"lines_total\":4,\"percent\":50.0},",
    "\"minimum_percent\":80.0}\n",
  ])
}

fn empty_json() {
  string.concat([
    "{\"version\":1,\"files\":[],\"excluded_files\":[],",
    "\"total\":{\"lines_hit\":0,\"lines_total\":0,\"percent\":null},",
    "\"minimum_percent\":null}\n",
  ])
}

fn rounded_json() {
  string.concat([
    "{\"version\":1,\"files\":[",
    "{\"path\":\"src/a.gleam\",\"lines_hit\":2,\"lines_total\":3,\"percent\":66.6,",
    "\"missing\":[{\"first\":3,\"last\":3}],\"ignored\":[]}],",
    "\"excluded_files\":[],",
    "\"total\":{\"lines_hit\":2,\"lines_total\":3,\"percent\":66.6},",
    "\"minimum_percent\":null}\n",
  ])
}

pub fn tests() {
  describe("dream_test/coverage/json_summary", [
    it("renders files, ignored lines, excluded files, total and minimum", fn() {
      json_summary.render(report: full_report(), minimum_percent: Some(80.0))
      |> should
      |> be_equal(full_json())
      |> or_fail_with("expected the full JSON summary")
    }),
    it("renders an empty report with null percents and no minimum", fn() {
      json_summary.render(report: report.new([]), minimum_percent: None)
      |> should
      |> be_equal(empty_json())
      |> or_fail_with("expected the empty JSON summary")
    }),
    it("rounds percents down to one decimal place", fn() {
      report.new([
        report.file("src/a.gleam", [
          LineCoverage(line: 1, calls: 1),
          LineCoverage(line: 2, calls: 1),
          LineCoverage(line: 3, calls: 0),
        ]),
      ])
      |> json_summary.render(minimum_percent: None)
      |> should
      |> be_equal(rounded_json())
      |> or_fail_with("expected 66.6")
    }),
  ])
}
