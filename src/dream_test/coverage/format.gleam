//// Text for the parts of a coverage report.
////
//// The coverage table and the Markdown summary use these functions, so both
//// write percents, line ranges and exclusions the same way. A custom
//// reporter can use them to match that text.
////
//// ```gleam
//// import dream_test/coverage/format
////
//// format.percent(hit: 18, total: 20)
//// // -> "90.0%"
//// ```
////
//// Percents round down, so `100.0%` means every line ran.
////
//// ## Available Functions
////
//// | Category       | Functions                                         |
//// |----------------|---------------------------------------------------|
//// | **Counts**     | `percent`, `line_counts`, `file_count`            |
//// | **Lines**      | `line_range`, `missed_lines`                      |
//// | **Exclusions** | `ignored_range`, `excluded_file`, `excluded_summary` |
////
//// ## Import Style
////
//// ```gleam
//// import dream_test/coverage/format
//// ```

import dream_test/coverage/report.{
  type CoverageReport, type ExcludedFile, type FileCoverage, type IgnoredRange,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

/// Write `hit / total` as a percent with one decimal place.
///
/// The percent rounds down, so `100.0%` means every line ran. With no
/// executable lines, the text is `-`.
///
/// ## Parameters
///
/// - `hit`: the executable lines that ran
/// - `total`: the executable lines
///
/// ## Returns
///
/// The percent text, for example `96.6%`.
///
/// ## Example
///
/// ```gleam
/// format.percent(hit: 58, total: 60)
/// // -> "96.6%"
/// ```
pub fn percent(hit hit: Int, total total: Int) -> String {
  case total {
    0 -> "-"
    _ -> tenths_text(hit * 1000 / total)
  }
}

fn tenths_text(tenths: Int) -> String {
  int.to_string(tenths / 10) <> "." <> int.to_string(tenths % 10) <> "%"
}

/// Write the lines that ran and the executable lines as `hit/total`.
///
/// ## Parameters
///
/// - `hit`: the executable lines that ran
/// - `total`: the executable lines
///
/// ## Returns
///
/// The counts text, for example `18/20`.
///
/// ## Example
///
/// ```gleam
/// format.line_counts(hit: 18, total: 20)
/// // -> "18/20"
/// ```
pub fn line_counts(hit hit: Int, total total: Int) -> String {
  int.to_string(hit) <> "/" <> int.to_string(total)
}

/// Write a range of line numbers.
///
/// ## Parameters
///
/// - `first`: the first line of the range
/// - `last`: the last line of the range
///
/// ## Returns
///
/// `first-last`, or only the number when the range has one line.
///
/// ## Example
///
/// ```gleam
/// format.line_range(first: 12, last: 13)
/// // -> "12-13"
/// ```
pub fn line_range(first first: Int, last last: Int) -> String {
  case first == last {
    True -> int.to_string(first)
    False -> int.to_string(first) <> "-" <> int.to_string(last)
  }
}

/// Write the lines of a file that did not run, as ranges.
///
/// ## Parameters
///
/// - `file`: the file to read
///
/// ## Returns
///
/// One text per range of `report.missed_ranges`, in line order.
///
/// ## Example
///
/// ```gleam
/// report.file("src/a.gleam", [
///   LineCoverage(line: 12, calls: 0),
///   LineCoverage(line: 13, calls: 0),
///   LineCoverage(line: 20, calls: 0),
/// ])
/// |> format.missed_lines()
/// // -> ["12-13", "20"]
/// ```
pub fn missed_lines(file file: FileCoverage) -> List(String) {
  list.map(report.missed_ranges(file), range_text)
}

fn range_text(range: #(Int, Int)) -> String {
  line_range(first: range.0, last: range.1)
}

/// Write the lines that an ignore marker left out, with the reason.
///
/// ## Parameters
///
/// - `range`: the ignored range
///
/// ## Returns
///
/// The range, then the reason in parentheses when the marker has one.
///
/// ## Example
///
/// ```gleam
/// report.ignored_range(first_line: 40, last_line: 44, reason: Some("debug only"))
/// |> format.ignored_range()
/// // -> "40-44 (debug only)"
/// ```
pub fn ignored_range(range range: IgnoredRange) -> String {
  line_range(
    first: report.ignored_first_line(range),
    last: report.ignored_last_line(range),
  )
  <> reason_suffix(report.ignored_reason(range))
}

/// Write why a pattern left a file out.
///
/// ## Parameters
///
/// - `file`: the excluded file
///
/// ## Returns
///
/// `excluded: matches` and the pattern, then the reason in parentheses when
/// the pattern has one.
///
/// ## Example
///
/// ```gleam
/// report.excluded_file(
///   source_path: "src/app/generated/db.gleam",
///   pattern: "src/app/generated/**",
///   reason: Some("generated code"),
/// )
/// |> format.excluded_file()
/// // -> "excluded: matches src/app/generated/** (generated code)"
/// ```
pub fn excluded_file(file file: ExcludedFile) -> String {
  "excluded: matches "
  <> report.excluded_pattern(file)
  <> reason_suffix(report.excluded_reason(file))
}

fn reason_suffix(reason: Option(String)) -> String {
  case reason {
    Some(text) -> " (" <> text <> ")"
    None -> ""
  }
}

/// Count what a report left out.
///
/// ## Parameters
///
/// - `report`: the report to read
///
/// ## Returns
///
/// - `Some` with the excluded files and the ignored lines, for example
///   `Excluded: 1 file, 6 lines in 1 file`
/// - `None` when the report left nothing out
///
/// ## Example
///
/// ```gleam
/// report.new([])
/// |> format.excluded_summary()
/// // -> None
/// ```
pub fn excluded_summary(
  report coverage_report: CoverageReport,
) -> Option(String) {
  let excluded_count = list.length(report.excluded_files(coverage_report))
  let files_with_ranges =
    list.filter(report.files(coverage_report), has_ignored_ranges)
  let line_count = list.fold(files_with_ranges, 0, add_ignored_line_count)
  let ranges_text =
    lines_in_files_text(line_count, list.length(files_with_ranges))
  case excluded_count, line_count {
    0, 0 -> None
    _, 0 -> Some("Excluded: " <> file_count(excluded_count))
    0, _ -> Some("Excluded: " <> ranges_text)
    _, _ ->
      Some("Excluded: " <> file_count(excluded_count) <> ", " <> ranges_text)
  }
}

fn has_ignored_ranges(file: FileCoverage) -> Bool {
  !list.is_empty(report.ignored_ranges(file))
}

fn add_ignored_line_count(total: Int, file: FileCoverage) -> Int {
  list.fold(report.ignored_ranges(file), total, add_range_line_count)
}

fn add_range_line_count(total: Int, range: IgnoredRange) -> Int {
  total + report.ignored_last_line(range) - report.ignored_first_line(range) + 1
}

fn lines_in_files_text(line_count: Int, files: Int) -> String {
  count_text(line_count, "line") <> " in " <> file_count(files)
}

/// Write a count of files: `1 file`, `2 files`.
///
/// ## Parameters
///
/// - `count`: how many files
///
/// ## Returns
///
/// The count and the word `file`, plural when the count is not 1.
///
/// ## Example
///
/// ```gleam
/// format.file_count(2)
/// // -> "2 files"
/// ```
pub fn file_count(count count: Int) -> String {
  count_text(count, "file")
}

fn count_text(count: Int, noun: String) -> String {
  case count {
    1 -> "1 " <> noun
    _ -> int.to_string(count) <> " " <> noun <> "s"
  }
}
