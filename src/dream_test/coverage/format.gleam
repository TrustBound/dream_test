//// Text for the parts of a coverage report.
////
//// The coverage table, the Markdown summary and the HTML report use these
//// functions, so they write percents, line ranges and exclusions the same
//// way. A custom
//// reporter can use them to match that text.
////
//// ### Write a percent <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/coverage/format/module.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_test/coverage/format
////
//// pub fn ninety_percent() -> String {
////   format.percent(hit: 18, total: 20)
////   // -> "90.0%"
//// }
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
//// | **Markup**     | `escape_markup`                                   |
////
//// ## Import Style
////
//// ### Import the format module <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/coverage/format/module_import_style.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_test/coverage/format
////
//// pub fn all_lines_ran() -> String {
////   format.percent(hit: 20, total: 20)
////   // -> "100.0%"
//// }
//// ```

import dream_test/coverage/report.{
  type CoverageReport, type ExcludedFile, type FileCoverage, type IgnoredRange,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

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
/// ### Write a percent that rounds down <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/coverage/format/percent.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/coverage/format
///
/// pub fn percent_rounds_down() -> String {
///   format.percent(hit: 58, total: 60)
///   // -> "96.6%"
/// }
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
/// ### Write the line counts <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/coverage/format/line_counts.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/coverage/format
///
/// pub fn eighteen_of_twenty() -> String {
///   format.line_counts(hit: 18, total: 20)
///   // -> "18/20"
/// }
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
/// ### Write a line range <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/coverage/format/line_range.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/coverage/format
///
/// pub fn lines_twelve_to_thirteen() -> String {
///   format.line_range(first: 12, last: 13)
///   // -> "12-13"
/// }
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
/// ### Write the missed lines of a file <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/coverage/format/missed_lines.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/coverage/format
/// import dream_test/coverage/report.{LineCoverage}
///
/// pub fn missed_lines_of_file() -> List(String) {
///   report.file("src/a.gleam", [
///     LineCoverage(line: 12, calls: 0),
///     LineCoverage(line: 13, calls: 0),
///     LineCoverage(line: 20, calls: 0),
///   ])
///   |> format.missed_lines()
///   // -> ["12-13", "20"]
/// }
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
/// ### Write an ignored range with its reason <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/coverage/format/ignored_range.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/coverage/format
/// import dream_test/coverage/report
/// import gleam/option.{Some}
///
/// pub fn debug_only_range_text() -> String {
///   report.ignored_range(
///     first_line: 40,
///     last_line: 44,
///     reason: Some("debug only"),
///   )
///   |> format.ignored_range()
///   // -> "40-44 (debug only)"
/// }
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
/// ### Write an excluded file with its reason <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/coverage/format/excluded_file.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/coverage/format
/// import dream_test/coverage/report
/// import gleam/option.{Some}
///
/// pub fn generated_file_text() -> String {
///   report.excluded_file(
///     source_path: "src/app/generated/db.gleam",
///     pattern: "src/app/generated/**",
///     reason: Some("generated code"),
///   )
///   |> format.excluded_file()
///   // -> "excluded: matches src/app/generated/** (generated code)"
/// }
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
/// ### Write the summary of a report with no exclusions <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/coverage/format/excluded_summary.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/coverage/format
/// import dream_test/coverage/report
/// import gleam/option.{type Option}
///
/// pub fn nothing_was_excluded() -> Option(String) {
///   report.new([])
///   |> format.excluded_summary()
///   // -> None
/// }
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
/// ### Write a file count <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/coverage/format/file_count.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/coverage/format
///
/// pub fn two_files() -> String {
///   format.file_count(2)
///   // -> "2 files"
/// }
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

/// Escape the five characters that HTML and XML give a meaning to.
///
/// `&` becomes `&amp;`, `<` becomes `&lt;`, `>` becomes `&gt;`, `"`
/// becomes `&quot;` and `'` becomes `&apos;`. The result is safe in element
/// text and in quoted attribute values. The Cobertura XML and the HTML report
/// escape every path, reason and source line with it.
///
/// ## Parameters
///
/// - `text`: the text to escape
///
/// ## Returns
///
/// The escaped text.
///
/// ## Example
///
/// ### Escape markup characters <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/coverage/format/escape_markup.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/coverage/format
///
/// pub fn escaped_comparison() -> String {
///   format.escape_markup("a < b && c")
///   // -> "a &lt; b &amp;&amp; c"
/// }
/// ```
pub fn escape_markup(text text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
  |> string.replace("'", "&apos;")
}
