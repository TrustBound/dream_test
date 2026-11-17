//// Coverage table reporter.
////
//// Renders a `dream_test/coverage.CoverageReport` as a plain-text table: one
//// row per source file with lines hit, executable lines and percent, then a
//// total row.
////
//// Most users do not call this module directly. `runner.coverage` prints the
//// table after the results reporters.
////
//// ## Example output
////
//// ```text
//// Coverage
//// File                      Lines  Cover
//// src/app/cart.gleam        18/20  90.0%
//// src/app/types.gleam       0/0    -
//// Total                     18/20  90.0%
//// LCOV: build/coverage/lcov.info
//// ```
////
//// Percentages round down, so a file shows `100.0%` only when every line ran.
//// A file with no executable lines shows `-`.

import dream_test/coverage.{
  type CoverageReport, type FileCoverage, executable_line_count, hit_line_count,
}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string

type CoverageRow {
  CoverageRow(label: String, lines: String, percent: String)
}

type ColumnWidths {
  ColumnWidths(label: Int, lines: Int)
}

/// Render a coverage report as a table.
///
/// The result ends with a newline.
///
/// ## Example
///
/// ```gleam
/// CoverageReport(files: [
///   FileCoverage(source_path: "src/a.gleam", lines: [
///     LineCoverage(line: 1, calls: 1),
///     LineCoverage(line: 2, calls: 0),
///   ]),
/// ], lcov_path: None)
/// |> coverage_reporter.render()
/// // -> "\nCoverage\nFile         Lines  Cover\nsrc/a.gleam  1/2    50.0%\nTotal        1/2    50.0%\n"
/// ```
pub fn render(report report: CoverageReport) -> String {
  let file_rows = list.map(report.files, file_row)
  let total_row =
    row_from_counts(
      "Total",
      sum_hit_lines(report.files, 0),
      sum_executable_lines(report.files, 0),
    )
  let header_row = CoverageRow(label: "File", lines: "Lines", percent: "Cover")
  let rows = list.flatten([[header_row], file_rows, [total_row]])
  let widths = list.fold(rows, ColumnWidths(label: 0, lines: 0), widen_columns)

  "\nCoverage\n" <> render_rows(rows, widths, "") <> render_lcov_line(report)
}

fn file_row(file: FileCoverage) -> CoverageRow {
  row_from_counts(
    file.source_path,
    hit_line_count(file),
    executable_line_count(file),
  )
}

fn row_from_counts(label: String, hit: Int, total: Int) -> CoverageRow {
  CoverageRow(
    label: label,
    lines: int.to_string(hit) <> "/" <> int.to_string(total),
    percent: format_percent(hit, total),
  )
}

/// Format `hit / total` as a percent with one decimal place, rounded down.
fn format_percent(hit: Int, total: Int) -> String {
  case total {
    0 -> "-"
    _ -> format_tenths(hit * 1000 / total)
  }
}

fn format_tenths(tenths: Int) -> String {
  int.to_string(tenths / 10) <> "." <> int.to_string(tenths % 10) <> "%"
}

fn sum_hit_lines(files: List(FileCoverage), total: Int) -> Int {
  case files {
    [] -> total
    [file, ..rest] -> sum_hit_lines(rest, total + hit_line_count(file))
  }
}

fn sum_executable_lines(files: List(FileCoverage), total: Int) -> Int {
  case files {
    [] -> total
    [file, ..rest] ->
      sum_executable_lines(rest, total + executable_line_count(file))
  }
}

fn widen_columns(widths: ColumnWidths, row: CoverageRow) -> ColumnWidths {
  ColumnWidths(
    label: int.max(widths.label, string.length(row.label)),
    lines: int.max(widths.lines, string.length(row.lines)),
  )
}

fn render_rows(
  rows: List(CoverageRow),
  widths: ColumnWidths,
  rendered: String,
) -> String {
  case rows {
    [] -> rendered
    [row, ..rest] ->
      render_rows(rest, widths, rendered <> render_row(row, widths))
  }
}

fn render_row(row: CoverageRow, widths: ColumnWidths) -> String {
  string.pad_end(row.label, widths.label + 2, " ")
  <> string.pad_end(row.lines, widths.lines + 2, " ")
  <> row.percent
  <> "\n"
}

fn render_lcov_line(report: CoverageReport) -> String {
  case report.lcov_path {
    None -> ""
    Some(path) -> "LCOV: " <> path <> "\n"
  }
}
