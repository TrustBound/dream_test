//// Coverage as a Markdown table.
////
//// The table is GitHub-flavoured Markdown. On GitHub Actions, write it to
//// the job summary: pass the path in `$GITHUB_STEP_SUMMARY` to
//// `coverage.markdown_path`. Call `render` yourself to get the text without
//// a file, for example to post it as a pull request comment.
////
//// ### Write the table to the job summary <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/coverage/markdown/module.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_test/coverage.{type CoverageConfig}
////
//// pub fn write_job_summary(summary_path: String) -> CoverageConfig {
////   coverage.new()
////   |> coverage.markdown_path(summary_path)
//// }
//// ```
////
//// ## Example output
////
//// ```markdown
//// ## Coverage
////
//// | File | Lines | Cover | Missing | Excluded |
//// | --- | ---: | ---: | --- | --- |
//// | src/app/cart.gleam | 18/20 | 90.0% | 12-13 | 40-44 (debug only) |
//// | src/app/generated/db.gleam |  |  |  | excluded: matches src/app/generated/\*\* |
//// | Total | 18/20 | 90.0% |  |  |
////
//// Excluded: 1 file, 5 lines in 1 file
//// ```
////
//// Every file is listed, sorted by path. The table options of the coverage
//// table (`sort_by_coverage`, `hide_complete`, `color`) do not change it.
//// Text in a cell has its Markdown characters escaped with `\`, so a `|` or
//// a `*` in a path or a reason shows as written.
////
//// ## Import Style
////
//// ### Import the Markdown module <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/coverage/markdown/module_import_style.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_test/coverage/markdown
//// import dream_test/coverage/report
////
//// pub fn empty_table() -> String {
////   markdown.render(report.new([]))
//// }
//// ```

import dream_test/coverage/format
import dream_test/coverage/report.{
  type CoverageReport, type ExcludedFile, type FileCoverage,
}
import gleam/list
import gleam/option.{None, Some}
import gleam/string

/// Render a coverage report as a Markdown table.
///
/// ## Parameters
///
/// - `report`: the report to render
///
/// ## Returns
///
/// A `## Coverage` heading, the table, and an `Excluded:` line when the
/// report left files or lines out. The text ends with a newline.
///
/// ## Example
///
/// ### Render a report as a Markdown table <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/coverage/markdown/render.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/coverage/markdown
/// import dream_test/coverage/report.{LineCoverage}
///
/// pub fn half_covered_table() -> String {
///   report.new([
///     report.file("src/a.gleam", [
///       LineCoverage(line: 1, calls: 1),
///       LineCoverage(line: 2, calls: 0),
///     ]),
///   ])
///   |> markdown.render()
///   // -> "## Coverage\n\n| File | Lines | Cover | Missing | Excluded |\n| --- | ---: | ---: | --- | --- |\n| src/a.gleam | 1/2 | 50.0% | 2 |  |\n| Total | 1/2 | 50.0% |  |  |\n"
/// }
/// ```
pub fn render(report coverage_report: CoverageReport) -> String {
  let hit = report.total_hit_line_count(coverage_report)
  let total = report.total_executable_line_count(coverage_report)
  string.concat([
    "## Coverage\n\n",
    "| File | Lines | Cover | Missing | Excluded |\n",
    "| --- | ---: | ---: | --- | --- |\n",
    string.concat(list.map(report.files(coverage_report), file_row)),
    string.concat(list.map(
      report.excluded_files(coverage_report),
      excluded_file_row,
    )),
    row([
      "Total",
      format.line_counts(hit: hit, total: total),
      format.percent(hit: hit, total: total),
      "",
      "",
    ]),
    excluded_summary(coverage_report),
  ])
}

fn file_row(file: FileCoverage) -> String {
  let hit = report.hit_line_count(file)
  let total = report.executable_line_count(file)
  row([
    report.source_path(file),
    format.line_counts(hit: hit, total: total),
    format.percent(hit: hit, total: total),
    string.join(format.missed_lines(file), ", "),
    string.join(
      list.map(report.ignored_ranges(file), format.ignored_range),
      ", ",
    ),
  ])
}

fn excluded_file_row(file: ExcludedFile) -> String {
  row([
    report.excluded_source_path(file),
    "",
    "",
    "",
    format.excluded_file(file),
  ])
}

fn row(cells: List(String)) -> String {
  "| " <> string.join(list.map(cells, escape), " | ") <> " |\n"
}

fn excluded_summary(coverage_report: CoverageReport) -> String {
  case format.excluded_summary(coverage_report) {
    Some(summary) -> "\n" <> summary <> "\n"
    None -> ""
  }
}

/// Put a `\` before each character that Markdown or a table cell gives a
/// meaning to. The backslash goes first, so it is not escaped twice.
fn escape(text: String) -> String {
  list.fold(markdown_characters, text, escape_character)
}

const markdown_characters = [
  "\\", "|", "*", "_", "`", "[", "]", "<", ">", "#", "~",
]

fn escape_character(text: String, character: String) -> String {
  string.replace(text, character, "\\" <> character)
}
