//// Coverage as a JSON summary.
////
//// `coverage.json_path` writes this summary to a file when coverage
//// finishes. Call `render` yourself to get the text without a file, for
//// example to send it to another service.
////
//// ```gleam
//// import dream_test/coverage
////
//// coverage.new()
//// |> coverage.json_path("build/coverage/coverage.json")
//// ```
////
//// ## Schema
////
//// The keys are always in this order. A new key is only added at the end of
//// an object, and `version` changes when a key changes meaning.
////
//// ```text
//// {
////   "version": 1,
////   "files": [
////     {
////       "path": "src/app/cart.gleam",         // relative to the project root
////       "lines_hit": 18,                       // executable lines that ran
////       "lines_total": 20,                     // executable lines
////       "percent": 90.0,                       // rounded down; null with no lines
////       "missing": [{"first": 12, "last": 13}],
////       "ignored": [{"first": 40, "last": 44, "reason": "debug only"}]
////     }
////   ],
////   "excluded_files": [
////     {"path": "src/app/generated/db.gleam",
////      "pattern": "src/app/generated/**",
////      "reason": "generated code"}         // null when there is no reason
////   ],
////   "total": {"lines_hit": 18, "lines_total": 20, "percent": 90.0},
////   "minimum_percent": 80.0,                  // null when no minimum is set
////   "minimum_percent_per_file": 50.0          // null when no per-file minimum
//// }
//// ```
////
//// `minimum_percent` comes from `coverage.minimum_percent` and
//// `minimum_percent_per_file` from `coverage.minimum_percent_per_file`.
////
//// Files are sorted by path. Excluded files and ignored lines are never
//// counted in `lines_hit` or `lines_total`.
////
//// ## Import Style
////
//// ```gleam
//// import dream_test/coverage/json_summary
//// ```

import dream_test/coverage/report.{
  type CoverageReport, type ExcludedFile, type FileCoverage, type IgnoredRange,
}
import gleam/int
import gleam/json.{type Json}
import gleam/option.{type Option, None, Some}

/// The settings that `render` writes into the summary next to the report.
///
/// Build one with `json_summary.options`, then set values with
/// `json_summary.minimum_percent` and `json_summary.minimum_percent_per_file`.
/// `coverage.json_path` fills it from your coverage settings.
pub opaque type Options {
  Options(
    minimum_percent: Option(Float),
    minimum_percent_per_file: Option(Float),
  )
}

/// Options with no values set: both minimums render as `null`.
///
/// ## Returns
///
/// The options with no minimum and no per-file minimum.
///
/// ## Example
///
/// ```gleam
/// json_summary.render(report: coverage_report, options: json_summary.options())
/// ```
pub fn options() -> Options {
  Options(minimum_percent: None, minimum_percent_per_file: None)
}

/// Set the minimum for the whole run, rendered as `minimum_percent`.
///
/// ## Parameters
///
/// - `options`: the options to change
/// - `percent`: the minimum, as given to `coverage.minimum_percent`
///
/// ## Returns
///
/// The updated options.
///
/// ## Example
///
/// ```gleam
/// json_summary.options()
/// |> json_summary.minimum_percent(80.0)
/// ```
pub fn minimum_percent(
  options options: Options,
  percent percent: Float,
) -> Options {
  Options(..options, minimum_percent: Some(percent))
}

/// Set the minimum for each file, rendered as `minimum_percent_per_file`.
///
/// ## Parameters
///
/// - `options`: the options to change
/// - `percent`: the minimum, as given to `coverage.minimum_percent_per_file`
///
/// ## Returns
///
/// The updated options.
///
/// ## Example
///
/// ```gleam
/// json_summary.options()
/// |> json_summary.minimum_percent_per_file(50.0)
/// ```
pub fn minimum_percent_per_file(
  options options: Options,
  percent percent: Float,
) -> Options {
  Options(..options, minimum_percent_per_file: Some(percent))
}

/// Render a coverage report as a JSON summary.
///
/// ## Parameters
///
/// - `report`: the report to render
/// - `options`: the minimums to write next to the report, from
///   `json_summary.options`
///
/// ## Returns
///
/// One line of JSON in the schema above, with a newline at the end.
///
/// ## Example
///
/// ```gleam
/// report.new([
///   report.file("src/a.gleam", [
///     LineCoverage(line: 1, calls: 1),
///     LineCoverage(line: 2, calls: 0),
///   ]),
/// ])
/// |> json_summary.render(options: json_summary.options())
/// // -> "{\"version\":1,\"files\":[{\"path\":\"src/a.gleam\",\"lines_hit\":1,\"lines_total\":2,\"percent\":50.0,\"missing\":[{\"first\":2,\"last\":2}],\"ignored\":[]}],\"excluded_files\":[],\"total\":{\"lines_hit\":1,\"lines_total\":2,\"percent\":50.0},\"minimum_percent\":null,\"minimum_percent_per_file\":null}\n"
/// ```
pub fn render(
  report coverage_report: CoverageReport,
  options options: Options,
) -> String {
  let hit = report.total_hit_line_count(coverage_report)
  let total = report.total_executable_line_count(coverage_report)
  json.object([
    #("version", json.int(1)),
    #("files", json.array(report.files(coverage_report), file_json)),
    #(
      "excluded_files",
      json.array(report.excluded_files(coverage_report), excluded_file_json),
    ),
    #("total", counts_json(hit, total)),
    #("minimum_percent", json.nullable(options.minimum_percent, json.float)),
    #(
      "minimum_percent_per_file",
      json.nullable(options.minimum_percent_per_file, json.float),
    ),
  ])
  |> json.to_string()
  |> append_newline()
}

fn append_newline(text: String) -> String {
  text <> "\n"
}

fn file_json(file: FileCoverage) -> Json {
  let hit = report.hit_line_count(file)
  let total = report.executable_line_count(file)
  json.object([
    #("path", json.string(report.source_path(file))),
    #("lines_hit", json.int(hit)),
    #("lines_total", json.int(total)),
    #("percent", percent_json(hit, total)),
    #("missing", json.array(report.missed_ranges(file), missed_range_json)),
    #("ignored", json.array(report.ignored_ranges(file), ignored_range_json)),
  ])
}

fn counts_json(hit: Int, total: Int) -> Json {
  json.object([
    #("lines_hit", json.int(hit)),
    #("lines_total", json.int(total)),
    #("percent", percent_json(hit, total)),
  ])
}

/// One decimal place, rounded down like the table, so `100.0` means every
/// line ran. No executable lines gives `null`.
fn percent_json(hit: Int, total: Int) -> Json {
  case total {
    0 -> json.null()
    _ -> json.float(int.to_float(hit * 1000 / total) /. 10.0)
  }
}

fn missed_range_json(range: #(Int, Int)) -> Json {
  json.object([#("first", json.int(range.0)), #("last", json.int(range.1))])
}

fn ignored_range_json(range: IgnoredRange) -> Json {
  json.object([
    #("first", json.int(report.ignored_first_line(range))),
    #("last", json.int(report.ignored_last_line(range))),
    #("reason", json.nullable(report.ignored_reason(range), json.string)),
  ])
}

fn excluded_file_json(file: ExcludedFile) -> Json {
  json.object([
    #("path", json.string(report.excluded_source_path(file))),
    #("pattern", json.string(report.excluded_pattern(file))),
    #("reason", json.nullable(report.excluded_reason(file), json.string)),
  ])
}
