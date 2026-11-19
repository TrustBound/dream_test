//// Coverage table reporter.
////
//// Renders a `dream_test/coverage/report.CoverageReport` as a plain-text
//// table: one row per source file with lines hit, executable lines and
//// percent, then a total row. `render_failure` renders a `CoverageError` as a
//// `Coverage failed` block that says what failed, why, and what to do.
////
//// `runner.coverage` calls both for you. Call them yourself when you run
//// coverage with `coverage.start` and `coverage.finish`, for example from
//// another test runner.
////
//// ```gleam
//// import dream_test/coverage
//// import dream_test/reporters/coverage as coverage_reporter
////
//// let config = coverage.new()
//// let assert Ok(session) = coverage.start(config)
//// run_my_tests()
//// let assert Ok(coverage_report) = coverage.finish(session)
//// io.print(coverage_reporter.render(report: coverage_report, config: config))
//// ```
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
//// With `coverage.show_missing()`, a `Missing` column lists the lines that
//// did not run, as ranges:
////
//// ```text
//// File                      Lines  Cover  Missing
//// src/app/cart.gleam        18/20  90.0%  12-13
//// ```
////
//// When a pattern excludes a file or a marker ignores a line, an `Excluded:`
//// line after the total counts them. With `coverage.show_excluded()`, an
//// `Excluded` column lists the ignored lines with their reasons, and a row
//// names each excluded file with its pattern and reason:
////
//// ```text
//// File                        Lines  Cover  Excluded
//// src/app/cart.gleam          18/20  90.0%  40-44 (debug only), 71
//// src/app/generated/db.gleam  excluded: matches src/app/generated/**
//// Total                       18/20  90.0%
//// Excluded: 1 file, 6 lines in 1 file
//// ```
////
//// `coverage.sort_by_coverage()` lists the lowest coverage first.
//// `coverage.hide_complete()` leaves out the files where every line ran and
//// says how many it left out:
////
//// ```text
//// File                Lines  Cover
//// src/app/cart.gleam  18/20  90.0%
//// Total               58/60  96.6%
//// Hidden: 2 files at 100.0%
//// ```
////
//// `coverage.color()` prints the `Cover` cell green at `100.0%`, red below
//// `coverage.minimum_percent` and yellow in between, and the `Missing`
//// column red. With no minimum, or an invalid one, the `Cover` cell is
//// yellow from `50.0%` and red below `50.0%`.
////
//// When a Gleam version before 1.19 built a measured file, a warning after
//// the table names the file, because its line numbers may be off. The
//// warning does not fail the run:
////
//// ```text
//// Warning: coverage line numbers may be off in files that a Gleam version before 1.19 built:
////   src/app/cart.gleam
////   Reason: before 1.19, Gleam maps only the first line of each function ...
////   Fix: build and test with Gleam 1.19 or later (`gleam --version` shows the version).
//// ```
////
//// When coverage fails, `render_failure` prints a `Coverage failed` block
//// instead. The runner writes it to the error output.
////
//// Percentages round down, so a file shows `100.0%` only when every line ran.
//// A file with no executable lines shows `-`.

import dream_test/coverage.{
  type AnalysisCause, type CoverageConfig, type CoverageError,
  type FileBelowMinimum, type InstrumentCause, type LoadCause,
  AlreadyInstrumented, BadBeamFile, BelowMinimumPercent, CoberturaWriteFailed,
  CompilerNotLoaded, DebugInfoUnreadable, EmbeddedMode, EncryptedDebugInfo,
  EverySourceFileExcluded, ExcludeMatchedNothing, ExcludeWithoutReason,
  FilesBelowMinimumPercent, HtmlDeleteFailed, HtmlFileSourceReadFailed,
  HtmlFileWriteFailed, HtmlSourceReadFailed, HtmlWriteFailed,
  IgnoreEndWithoutStart, IgnoreFunctionWithoutFunction, IgnoreLineWithoutCode,
  IgnoreMarkerWithoutReason, IgnoreStartWithoutEnd, InstrumentedLoadFailed,
  InvalidEnvironmentValue, InvalidMinimumPercent, InvalidMinimumPercentPerFile,
  JsonWriteFailed, LcovReadFailed, LcovSourceNotFound, LcovWriteFailed,
  MalformedLcov, MarkdownWriteFailed, ModuleAlreadyMeasured, ModuleNotAnalysed,
  ModuleNotBuilt, ModuleNotInstrumented, ModuleNotLoaded,
  NativeCoverageUnsupported, NestedIgnoreStart, NoDebugInfo, NoLcovFilesMatched,
  NoSourceFiles, NotInstrumented, OldCodeInUse, OnLoadFailed, RecompileFailed,
  SessionAlreadyFinished, SourceDirectoryNotFound,
  SourceDirectoryOutsideSourceRoot, SourceReadFailed,
}
import dream_test/coverage/format
import dream_test/coverage/report.{
  type CoverageReport, type ExcludedFile, type FileCoverage,
}
import dream_test/file.{type FileError}
import dream_test/reporters/ansi
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order}
import gleam/result
import gleam/string

/// How the test run ended, for the last line of a coverage failure.
///
/// - `passed`: tests with status `Passed`
/// - `failed`: tests with status `Failed`, `SetupFailed` or `TimedOut`
/// - `teardown_failed`: tear-down hooks that failed
/// - `setup_stopped`: set-ups whose process stopped while their tests ran
/// - `exit_on_failure`: whether the runner exits with status 1 on failure
pub type RunOutcome {
  RunOutcome(
    passed: Int,
    failed: Int,
    teardown_failed: Int,
    setup_stopped: Int,
    exit_on_failure: Bool,
  )
}

/// One row of the table. A row can take more than one line of output when
/// its `Missing` or `Excluded` cell wraps.
type CoverageRow {
  /// `measured` is where the counts come from. Colours come from it.
  CountsRow(
    measured: Measured,
    label: String,
    lines: String,
    percent: String,
    missing: List(String),
    excluded: List(String),
  )
  /// A file that an exclude pattern left out. Its text starts in the
  /// `Lines` column.
  ExcludedFileRow(label: String, text: String)
}

/// Where the counts of a row come from.
type Measured {
  /// The header has no counts.
  NotMeasured
  /// A report that holds only the file of the row.
  MeasuredFile(report: CoverageReport)
  /// The whole report, for the total row.
  MeasuredTotal(report: CoverageReport)
}

/// Which of the optional columns the table shows.
type Columns {
  Columns(
    show_missing: Bool,
    show_excluded: Bool,
    color: Bool,
    config: CoverageConfig,
  )
}

/// The ANSI colour of a cell.
type CellColor {
  Plain
  Red
  Yellow
  Green
}

type ColumnWidths {
  ColumnWidths(label: Int, lines: Int, percent: Int, missing: Int)
}

/// The cells of one column of a row, one per output line, and the width
/// they are padded to.
type Cells {
  Cells(lines: List(String), width: Int, color: CellColor)
}

/// The widest the `Missing` and `Excluded` columns get before they wrap onto
/// another line.
const missing_column_width = 60

/// Render a coverage report as a table.
///
/// The settings decide:
///
/// - `coverage.show_missing` adds the `Missing` column.
/// - `coverage.show_excluded` adds the `Excluded` column and a row for each
///   excluded file.
/// - `coverage.sort_by_coverage` lists the lowest coverage first.
/// - `coverage.hide_complete` leaves out files where every line ran, and
///   adds a `Hidden:` line that counts them. The total still counts them.
/// - `coverage.color` adds ANSI colour codes to the `Cover` and `Missing`
///   cells.
/// - The LCOV path (`coverage.lcov_file`) is printed on the last line when
///   there is one.
///
/// When the report holds excluded files or ignored lines, an `Excluded:`
/// line after the total counts them, whether `coverage.show_excluded` is on
/// or off.
///
/// ## Parameters
///
/// - `report`: the report to render
/// - `config`: the coverage settings the report was made with
///
/// ## Returns
///
/// The table, starting with a blank line and ending with a newline.
///
/// ## Example
///
/// ```gleam
/// let coverage_report =
///   report.new([
///     report.file("src/a.gleam", [
///       LineCoverage(line: 1, calls: 1),
///       LineCoverage(line: 2, calls: 0),
///     ]),
///   ])
///
/// coverage_reporter.render(
///   report: coverage_report,
///   config: coverage.new() |> coverage.no_lcov(),
/// )
/// // -> "\nCoverage\nFile         Lines  Cover\nsrc/a.gleam  1/2    50.0%\nTotal        1/2    50.0%\n"
/// ```
pub fn render(
  report coverage_report: CoverageReport,
  config config: CoverageConfig,
) -> String {
  let columns =
    Columns(
      show_missing: coverage.shows_missing(config),
      show_excluded: coverage.shows_excluded(config),
      color: coverage.uses_color(config),
      config: config,
    )
  let all_files = report.files(coverage_report)
  let shown_files =
    all_files
    |> hide_complete_files(coverage.hides_complete(config))
    |> sort_files(coverage.sorts_by_coverage(config))
  let file_rows = list.map(shown_files, file_row)
  let excluded_file_rows =
    excluded_file_rows(columns, report.excluded_files(coverage_report))
  let total_row = total_row(coverage_report)
  let rows =
    list.flatten([
      [header_row()],
      file_rows,
      excluded_file_rows,
      [total_row],
    ])
  let widths =
    list.fold(
      rows,
      ColumnWidths(label: 0, lines: 0, percent: 0, missing: 0),
      widen_columns,
    )

  "\nCoverage\n"
  <> render_rows(rows, widths, columns, "")
  <> render_excluded_summary(coverage_report)
  <> render_hidden_summary(list.length(all_files) - list.length(shown_files))
  <> render_lcov_line(coverage.lcov_file(config))
  <> render_inexact_line_warning(report.inexact_line_files(coverage_report))
}

/// The header names every column. `row_cells` leaves out the columns that
/// the table does not show.
fn header_row() -> CoverageRow {
  CountsRow(
    measured: NotMeasured,
    label: "File",
    lines: "Lines",
    percent: "Cover",
    missing: ["Missing"],
    excluded: ["Excluded"],
  )
}

fn file_row(file: FileCoverage) -> CoverageRow {
  let hit = report.hit_line_count(file)
  let total = report.executable_line_count(file)
  CountsRow(
    measured: MeasuredFile(report.new([file])),
    label: report.source_path(file),
    lines: format.line_counts(hit: hit, total: total),
    percent: format.percent(hit: hit, total: total),
    missing: wrap_ranges(format.missed_lines(file), "", []),
    excluded: wrap_ranges(
      list.map(report.ignored_ranges(file), format.ignored_range),
      "",
      [],
    ),
  )
}

fn total_row(coverage_report: CoverageReport) -> CoverageRow {
  let hit = report.total_hit_line_count(coverage_report)
  let total = report.total_executable_line_count(coverage_report)
  CountsRow(
    measured: MeasuredTotal(coverage_report),
    label: "Total",
    lines: format.line_counts(hit: hit, total: total),
    percent: format.percent(hit: hit, total: total),
    missing: [],
    excluded: [],
  )
}

fn hide_complete_files(
  files: List(FileCoverage),
  hide_complete: Bool,
) -> List(FileCoverage) {
  case hide_complete {
    True -> list.filter(files, is_incomplete)
    False -> files
  }
}

/// A file shows `100.0%` only when it has executable lines and every one
/// ran. Files with no executable lines show `-` and are never hidden.
fn is_incomplete(file: FileCoverage) -> Bool {
  let total = report.executable_line_count(file)
  total == 0 || report.hit_line_count(file) < total
}

fn sort_files(
  files: List(FileCoverage),
  by_coverage: Bool,
) -> List(FileCoverage) {
  case by_coverage {
    True -> list.sort(files, compare_coverage)
    False -> files
  }
}

/// Lowest share of lines that ran first, then by path. The shares are
/// compared as exact fractions. A file with no executable lines counts as
/// fully covered.
fn compare_coverage(left: FileCoverage, right: FileCoverage) -> Order {
  let #(left_hit, left_total) = covered_share(left)
  let #(right_hit, right_total) = covered_share(right)
  int.compare(left_hit * right_total, right_hit * left_total)
  |> order.break_tie(string.compare(
    report.source_path(left),
    report.source_path(right),
  ))
}

fn covered_share(file: FileCoverage) -> #(Int, Int) {
  case report.executable_line_count(file) {
    0 -> #(1, 1)
    total -> #(report.hit_line_count(file), total)
  }
}

fn excluded_file_rows(
  columns: Columns,
  excluded_files: List(ExcludedFile),
) -> List(CoverageRow) {
  case columns.show_excluded {
    True -> list.map(excluded_files, excluded_file_row)
    False -> []
  }
}

fn excluded_file_row(excluded: ExcludedFile) -> CoverageRow {
  ExcludedFileRow(
    label: report.excluded_source_path(excluded),
    text: format.excluded_file(excluded),
  )
}

/// Join ranges with ", " into lines no wider than `missing_column_width`.
/// Every line but the last ends with a comma, which counts toward the width.
fn wrap_ranges(
  ranges: List(String),
  current: String,
  lines_reversed: List(String),
) -> List(String) {
  case ranges, current {
    [], "" -> list.reverse(lines_reversed)
    [], _ -> list.reverse([current, ..lines_reversed])
    [range, ..rest], "" -> wrap_ranges(rest, range, lines_reversed)
    [range, ..rest], _ -> add_range(range, rest, current, lines_reversed)
  }
}

fn add_range(
  range: String,
  rest: List(String),
  current: String,
  lines_reversed: List(String),
) -> List(String) {
  let joined = current <> ", " <> range
  case string.length(joined) + 1 > missing_column_width {
    True -> wrap_ranges(rest, range, [current <> ",", ..lines_reversed])
    False -> wrap_ranges(rest, joined, lines_reversed)
  }
}

fn widen_columns(widths: ColumnWidths, row: CoverageRow) -> ColumnWidths {
  case row {
    CountsRow(label:, lines:, percent:, missing:, ..) ->
      ColumnWidths(
        label: int.max(widths.label, string.length(label)),
        lines: int.max(widths.lines, string.length(lines)),
        percent: int.max(widths.percent, string.length(percent)),
        missing: list.fold(missing, widths.missing, widen_to_text),
      )
    ExcludedFileRow(label:, ..) ->
      ColumnWidths(..widths, label: int.max(widths.label, string.length(label)))
  }
}

fn widen_to_text(width: Int, text: String) -> Int {
  int.max(width, string.length(text))
}

fn render_rows(
  rows: List(CoverageRow),
  widths: ColumnWidths,
  columns: Columns,
  rendered: String,
) -> String {
  case rows {
    [] -> rendered
    [row, ..rest] ->
      render_rows(
        rest,
        widths,
        columns,
        rendered <> render_cells(row_cells(row, widths, columns), ""),
      )
  }
}

/// The columns of a row. Every column is padded two spaces past its width;
/// `render_cells` removes the spaces at the end of each output line.
fn row_cells(
  row: CoverageRow,
  widths: ColumnWidths,
  columns: Columns,
) -> List(Cells) {
  case row {
    CountsRow(measured:, label:, lines:, percent:, missing:, excluded:) ->
      list.flatten([
        [
          Cells(lines: [label], width: widths.label, color: Plain),
          Cells(lines: [lines], width: widths.lines, color: Plain),
          Cells(
            lines: [percent],
            width: widths.percent,
            color: percent_color(columns, measured),
          ),
        ],
        optional_cells(
          columns.show_missing,
          missing,
          widths.missing,
          missing_color(columns, measured),
        ),
        optional_cells(columns.show_excluded, excluded, 0, Plain),
      ])
    ExcludedFileRow(label:, text:) -> [
      Cells(lines: [label], width: widths.label, color: Plain),
      Cells(lines: [text], width: 0, color: Plain),
    ]
  }
}

fn optional_cells(
  shown: Bool,
  lines: List(String),
  width: Int,
  color: CellColor,
) -> List(Cells) {
  case shown {
    True -> [Cells(lines: lines, width: width, color: color)]
    False -> []
  }
}

/// Green at 100.0%. Below that, the minimum decides the colour when one is
/// set and valid, and a fixed rule decides it otherwise. The header and a
/// `-` cell stay plain.
fn percent_color(columns: Columns, measured: Measured) -> CellColor {
  case columns.color, measured {
    True, MeasuredFile(measured_report) ->
      measured_percent_color(
        file_minimum_check(columns.config, measured_report),
        measured_report,
      )
    True, MeasuredTotal(measured_report) ->
      measured_percent_color(
        total_minimum_check(columns.config, measured_report),
        measured_report,
      )
    _, _ -> Plain
  }
}

/// The result of the minimum check that decides a colour, or `None` when
/// no minimum applies.
type MinimumCheck =
  Option(Result(Nil, CoverageError))

/// A file row uses the per-file minimum when it is set, and the total
/// minimum otherwise.
fn file_minimum_check(
  config: CoverageConfig,
  measured_report: CoverageReport,
) -> MinimumCheck {
  case coverage.minimum_per_file(config) {
    Some(_) -> Some(coverage.check_minimum_per_file(config, measured_report))
    None -> total_minimum_check(config, measured_report)
  }
}

fn total_minimum_check(
  config: CoverageConfig,
  measured_report: CoverageReport,
) -> MinimumCheck {
  case coverage.minimum(config) {
    Some(_) -> Some(coverage.check_minimum(config, measured_report))
    None -> None
  }
}

fn measured_percent_color(
  check: MinimumCheck,
  measured_report: CoverageReport,
) -> CellColor {
  let hit = report.total_hit_line_count(measured_report)
  let total = report.total_executable_line_count(measured_report)
  case total, hit == total {
    0, _ -> Plain
    _, True -> Green
    _, False -> incomplete_color(check, hit, total)
  }
}

/// With a valid minimum, `coverage.check_minimum` decides "below the
/// minimum", so the colour matches the minimum check exactly: red below it,
/// yellow at it or above. With no minimum, or an invalid one (the runner
/// reports that as its own failure), the fixed rule decides.
fn incomplete_color(check: MinimumCheck, hit: Int, total: Int) -> CellColor {
  case check {
    Some(Ok(Nil)) -> Yellow
    Some(Error(BelowMinimumPercent(..)))
    | Some(Error(FilesBelowMinimumPercent(..))) -> Red
    _ -> fixed_rule_color(hit, total)
  }
}

/// Yellow at 50% or above, red below 50%. The comparison is exact.
fn fixed_rule_color(hit: Int, total: Int) -> CellColor {
  case hit * 2 >= total {
    True -> Yellow
    False -> Red
  }
}

/// The lines that did not run are red. The header stays plain.
fn missing_color(columns: Columns, measured: Measured) -> CellColor {
  case columns.color, measured {
    True, MeasuredFile(_) | True, MeasuredTotal(_) -> Red
    _, _ -> Plain
  }
}

/// Render the first cell of each column as one output line, then go on with
/// the cells after them until every column is empty.
fn render_cells(cells: List(Cells), rendered: String) -> String {
  case list.all(cells, has_no_lines) {
    True -> rendered
    False ->
      render_cells(
        list.map(cells, without_first_line),
        rendered
          <> string.trim_end(string.concat(list.map(cells, first_line_padded)))
          <> "\n",
      )
  }
}

fn has_no_lines(cells: Cells) -> Bool {
  list.is_empty(cells.lines)
}

fn without_first_line(cells: Cells) -> Cells {
  Cells(..cells, lines: list.drop(cells.lines, 1))
}

/// The padding goes after the colour codes, so the codes do not change the
/// column widths.
fn first_line_padded(cells: Cells) -> String {
  let text = result.unwrap(list.first(cells.lines), "")
  paint(cells.color, text)
  <> string.repeat(" ", cells.width + 2 - string.length(text))
}

fn paint(color: CellColor, text: String) -> String {
  case color, text {
    _, "" -> ""
    Plain, _ -> text
    Red, _ -> ansi.red(text)
    Yellow, _ -> ansi.yellow(text)
    Green, _ -> ansi.green(text)
  }
}

/// `Excluded: 1 file, 6 lines in 1 file`, or nothing when nothing is
/// excluded.
fn render_excluded_summary(coverage_report: CoverageReport) -> String {
  case format.excluded_summary(coverage_report) {
    Some(summary) -> summary <> "\n"
    None -> ""
  }
}

/// `Hidden: 2 files at 100.0%`, or nothing when no file was hidden.
fn render_hidden_summary(hidden_count: Int) -> String {
  case hidden_count {
    0 -> ""
    _ -> "Hidden: " <> format.file_count(hidden_count) <> " at 100.0%\n"
  }
}

fn render_lcov_line(lcov_path: option.Option(String)) -> String {
  case lcov_path {
    None -> ""
    Some(path) -> "LCOV: " <> path <> "\n"
  }
}

/// The warning for files that a Gleam version before 1.19 built. It is not a
/// failure: the counts are right, only line numbers can be off.
fn render_inexact_line_warning(source_paths: List(String)) -> String {
  case source_paths {
    [] -> ""
    _ ->
      "\nWarning: coverage line numbers may be off in files that a Gleam version before 1.19 built:\n"
      <> string.concat(list.map(source_paths, indent_line))
      <> "  Reason: before 1.19, Gleam maps only the first line of each function to its source line, so other lines in a function can show the wrong number in the Missing column, the LCOV file and coverage:ignore markers.\n"
      <> "  Fix: build and test with Gleam 1.19 or later (`gleam --version` shows the version).\n"
  }
}

/// Render a coverage failure as a block that is easy to see after the
/// test results.
///
/// The block has a `Coverage failed` heading; three indented lines that say
/// what failed and where, the likely reason (with the raw Erlang term in
/// brackets, when there is one), and how to fix it; and a last line that says
/// how the tests ended and why the exit status is what it is.
///
/// ## Parameters
///
/// - `error`: the coverage error
/// - `outcome`: how the test run ended
///
/// ## Returns
///
/// The block, starting with a blank line and ending with a newline.
///
/// ## Example
///
/// ```gleam
/// coverage_reporter.render_failure(
///   error: NoSourceFiles("lib"),
///   outcome: RunOutcome(
///     passed: 3,
///     failed: 0,
///     teardown_failed: 0,
///     setup_stopped: 0,
///     exit_on_failure: True,
///   ),
/// )
/// // -> "\nCoverage failed\n"
/// //    <> "  Found no .gleam or .erl files in the source directory \"lib\".\n"
/// //    <> "  Reason: the directory exists, but coverage has nothing in it to measure.\n"
/// //    <> "  Fix: set the directory that holds your code with coverage.source_directory(...).\n"
/// //    <> "\nTests: 3 passed. Exit status 1, because coverage was requested and did not complete.\n"
/// ```
pub fn render_failure(
  error error: CoverageError,
  outcome outcome: RunOutcome,
) -> String {
  let body =
    error_to_string(error)
    |> string.split("\n")
    |> list.map(indent_line)
    |> string.concat()

  "\nCoverage failed\n"
  <> body
  <> "\n"
  <> outcome_line(outcome, exit_reason(error))
  <> "\n"
}

fn indent_line(line: String) -> String {
  "  " <> line <> "\n"
}

/// Why coverage made the run fail: `alone` when nothing else failed, and
/// `coverage` to follow the other causes, as in
/// `tests failed and <coverage>`.
type ExitReason {
  ExitReason(alone: String, coverage: String)
}

fn exit_reason(error: CoverageError) -> ExitReason {
  case error {
    BelowMinimumPercent(..) | FilesBelowMinimumPercent(..) ->
      ExitReason(
        alone: "coverage is below the minimum",
        coverage: "coverage is below the minimum",
      )
    _ ->
      ExitReason(
        alone: "coverage was requested and did not complete",
        coverage: "coverage did not complete",
      )
  }
}

fn outcome_line(outcome: RunOutcome, reason: ExitReason) -> String {
  let tests = tests_line(outcome)
  case outcome.exit_on_failure {
    True ->
      tests <> " Exit status 1, because " <> causes(outcome, reason) <> "."
    False ->
      tests
      <> " The exit status is not changed, because exit_on_failure is off."
  }
}

/// The causes of the exit status 1, in a sentence. Failed tests come
/// first and alone; else each failed tear-down hook and stopped set-up.
fn causes(outcome: RunOutcome, reason: ExitReason) -> String {
  case outcome.failed, hook_causes(outcome) {
    0, [] -> reason.alone
    0, hooks -> string.join(hooks, ", ") <> " and " <> reason.coverage
    _, _ -> "tests failed and " <> reason.coverage
  }
}

fn hook_causes(outcome: RunOutcome) -> List(String) {
  list.flatten([
    cause_when(outcome.teardown_failed, "a tear-down hook failed"),
    cause_when(outcome.setup_stopped, "a set-up stopped"),
  ])
}

fn cause_when(count: Int, cause: String) -> List(String) {
  case count {
    0 -> []
    _ -> [cause]
  }
}

fn tests_line(outcome: RunOutcome) -> String {
  "Tests: "
  <> int.to_string(outcome.passed)
  <> " passed"
  <> count_part(outcome.failed, " failed")
  <> count_part(outcome.teardown_failed, " tear-down failed")
  <> count_part(outcome.setup_stopped, " set-up stopped")
  <> "."
}

/// `, <count><label>`, or `""` for a count of 0.
fn count_part(count: Int, label: String) -> String {
  case count {
    0 -> ""
    _ -> ", " <> int.to_string(count) <> label
  }
}

type ErrorMessage {
  ErrorMessage(what: String, reason: String, fix: String)
}

fn error_to_string(error: CoverageError) -> String {
  let message = error_message(error)
  message.what <> "\nReason: " <> message.reason <> "\nFix: " <> message.fix
}

fn error_message(error: CoverageError) -> ErrorMessage {
  case error {
    SourceDirectoryNotFound(path) ->
      ErrorMessage(
        what: "Could not find the source directory \"" <> path <> "\".",
        reason: "coverage measures the .gleam and .erl files in this directory, and no directory with this name exists where the tests run.",
        fix: "run `gleam test` from the project folder, or set the path with coverage.source_directory(...).",
      )
    SourceDirectoryOutsideSourceRoot(path) ->
      ErrorMessage(
        what: "Could not measure the source directory \"" <> path <> "\".",
        reason: "module names start at the src, test or dev folder, so coverage can only measure one of those folders or a folder inside one.",
        fix: "set coverage.source_directory(...) to src, test, dev or a folder inside one of them, for example src/app.",
      )
    NoSourceFiles(path) ->
      ErrorMessage(
        what: "Found no .gleam or .erl files in the source directory \""
          <> path
          <> "\".",
        reason: "the directory exists, but coverage has nothing in it to measure.",
        fix: "set the directory that holds your code with coverage.source_directory(...).",
      )
    NativeCoverageUnsupported(otp_release, emulator_flavor) ->
      ErrorMessage(
        what: "Could not count lines in this Erlang runtime (Erlang/OTP "
          <> otp_release
          <> ", "
          <> emulator_flavor
          <> " emulator).",
        reason: "coverage uses the native line counters of the BEAM, which need Erlang/OTP 27 or later with the JIT.",
        fix: "run the tests on Erlang/OTP 27 or later, on a platform where the JIT is on (x86-64 or ARM64).",
      )
    CompilerNotLoaded(_cause, raw) ->
      ErrorMessage(
        what: "Could not load the Erlang compiler.",
        reason: "coverage compiles each module again with line counters, and the compile module did not load ("
          <> raw
          <> ").",
        fix: "install the Erlang compiler application. In embedded mode, load it when the BEAM starts.",
      )
    ModuleAlreadyMeasured(module_name, source_path) ->
      ErrorMessage(
        what: "Could not measure module "
          <> describe_module(module_name, source_path)
          <> ".",
        reason: "another coverage run in this BEAM already measures this module, and two runs cannot share its line counters.",
        fix: "finish the other run with coverage.finish first, or give each run a source directory that the other does not measure.",
      )
    ModuleNotLoaded(module_name, source_path, cause, raw) ->
      load_message(describe_module(module_name, source_path), cause, raw)
    ModuleNotInstrumented(module_name, source_path, cause, raw) ->
      instrument_message(describe_module(module_name, source_path), cause, raw)
    ModuleNotAnalysed(module_name, source_path, cause, raw) ->
      analysis_message(describe_module(module_name, source_path), cause, raw)
    SessionAlreadyFinished ->
      ErrorMessage(
        what: "Could not finish the coverage session.",
        reason: "coverage.finish already ran for this session, or the process that called coverage.start ended and another coverage run then measured one of its modules.",
        fix: "call coverage.finish once for each session that coverage.start returns, from a process that is still running.",
      )
    LcovWriteFailed(path, error) -> write_message(lcov_output(), path, error)
    JsonWriteFailed(path, error) -> write_message(json_output(), path, error)
    CoberturaWriteFailed(path, error) ->
      write_message(cobertura_output(), path, error)
    MarkdownWriteFailed(path, error) ->
      write_message(markdown_output(), path, error)
    HtmlWriteFailed(path, error) -> write_message(html_output(), path, error)
    HtmlSourceReadFailed(path, error) ->
      ErrorMessage(
        what: "Could not read the source file \""
          <> path
          <> "\" to show it in the HTML coverage report.",
        reason: "the HTML report shows the source of each measured file, but this file cannot be read ("
          <> file.error_to_string(error)
          <> ").",
        fix: "make the file readable by the user that runs the tests, or remove coverage.html_path(...).",
      )
    HtmlFileWriteFailed(path, error) ->
      write_message(html_file_output(), path, error)
    HtmlFileSourceReadFailed(path, error) ->
      ErrorMessage(
        what: "Could not read the source file \""
          <> path
          <> "\" to show it in the combined HTML coverage page.",
        reason: "the combined HTML page shows the source of each measured file, but this file cannot be read ("
          <> file.error_to_string(error)
          <> ").",
        fix: "make the file readable by the user that runs the tests, or remove coverage.html_file(...).",
      )
    HtmlDeleteFailed(path, error) ->
      ErrorMessage(
        what: "Could not delete the old HTML coverage pages in \""
          <> path
          <> "\".",
        reason: "coverage.html_path(...) deletes this folder before it writes new pages, so that no page of a removed source file stays, but the folder cannot be deleted ("
          <> file.error_to_string(error)
          <> ").",
        fix: "make this folder and everything in it writable by the user that runs the tests, or delete the folder yourself.",
      )
    InvalidMinimumPercent(value) ->
      ErrorMessage(
        what: "The coverage minimum "
          <> float.to_string(value)
          <> " is not a percent.",
        reason: "coverage.minimum_percent(...) takes a value from 0.0 to 100.0.",
        fix: "pass a value from 0.0 to 100.0, for example coverage.minimum_percent(80.0).",
      )
    InvalidEnvironmentValue(name, value) ->
      ErrorMessage(
        what: "The environment variable "
          <> name
          <> " has the value \""
          <> value
          <> "\", which does not turn coverage on or off.",
        reason: "runner.coverage_from_environment(...) turns coverage on for 1 or true and off for 0 or false, and it does not guess what other values mean.",
        fix: "set "
          <> name
          <> " to 1 or true to measure coverage, or set it to 0 or false (or remove it) to run without coverage.",
      )
    BelowMinimumPercent(hit, total, minimum, lines_needed) ->
      below_minimum_message(hit, total, minimum, lines_needed)
    InvalidMinimumPercentPerFile(value) ->
      ErrorMessage(
        what: "The per-file coverage minimum "
          <> float.to_string(value)
          <> " is not a percent.",
        reason: "coverage.minimum_percent_per_file(...) takes a value from 0.0 to 100.0.",
        fix: "pass a value from 0.0 to 100.0, for example coverage.minimum_percent_per_file(70.0).",
      )
    FilesBelowMinimumPercent(minimum, files) ->
      files_below_minimum_message(minimum, files)
    NoLcovFilesMatched(pattern) ->
      ErrorMessage(
        what: "No LCOV files match \"" <> pattern <> "\".",
        reason: "coverage.merge_lcov(...) adds coverage written by other runs, and nothing has written a file that matches this pattern.",
        fix: "check that the other runs write their LCOV files to a path that matches before this run finishes, or remove coverage.merge_lcov(...).",
      )
    LcovReadFailed(path, error) ->
      ErrorMessage(
        what: "Could not read the LCOV file \"" <> path <> "\" to merge it.",
        reason: "the file matches coverage.merge_lcov(...), but it cannot be read ("
          <> file.error_to_string(error)
          <> ").",
        fix: "check that the path is a readable file, or change the pattern so it only matches LCOV files.",
      )
    MalformedLcov(path, line_number, line, problem) ->
      ErrorMessage(
        what: "The LCOV file \""
          <> path
          <> "\" is not valid at line "
          <> int.to_string(line_number)
          <> " (\""
          <> line
          <> "\").",
        reason: problem,
        fix: "check the tool that wrote this file, or delete the file and run the tests again.",
      )
    LcovSourceNotFound(lcov_path, source_path) ->
      ErrorMessage(
        what: "The LCOV file \""
          <> lcov_path
          <> "\" covers \""
          <> source_path
          <> "\", which does not exist.",
        reason: "merged coverage must be for files in this project, and SF paths are read from the directory the tests run in.",
        fix: "write SF paths relative to the project folder, or delete LCOV files left from an older version of the code.",
      )
    ExcludeMatchedNothing(pattern, source_directory) ->
      ErrorMessage(
        what: "No source file matches the exclude pattern \""
          <> pattern
          <> "\".",
        reason: "coverage.exclude(...) leaves files out of coverage, and no .gleam or .erl file in the source directory \""
          <> source_directory
          <> "\" matches this pattern.",
        fix: "write the pattern relative to the directory the tests run in, for example \"src/app/generated/**\", or remove coverage.exclude(...).",
      )
    EverySourceFileExcluded(source_directory) ->
      ErrorMessage(
        what: "Every .gleam and .erl file in the source directory \""
          <> source_directory
          <> "\" is excluded.",
        reason: "the coverage.exclude(...) patterns match all of the files, so coverage has nothing to measure.",
        fix: "make the coverage.exclude(...) patterns match fewer files, or set the directory that holds your code with coverage.source_directory(...).",
      )
    SourceReadFailed(path, error) ->
      ErrorMessage(
        what: "Could not read the source file \""
          <> path
          <> "\" to find its coverage:ignore markers.",
        reason: "coverage reads the markers of each measured file and of each file that a merged LCOV file covers, but this file cannot be read ("
          <> file.error_to_string(error)
          <> ").",
        fix: "make the file readable by the user that runs the tests.",
      )
    IgnoreStartWithoutEnd(source_path, line_number) ->
      ErrorMessage(
        what: "The coverage:ignore-start marker at "
          <> source_location(source_path, line_number)
          <> " has no coverage:ignore-end marker after it.",
        reason: "an ignored block runs from a coverage:ignore-start marker to the next coverage:ignore-end marker, so this block has no last line.",
        fix: "add a coverage:ignore-end marker on its own line after the last line to ignore.",
      )
    IgnoreEndWithoutStart(source_path, line_number) ->
      ErrorMessage(
        what: "The coverage:ignore-end marker at "
          <> source_location(source_path, line_number)
          <> " has no coverage:ignore-start marker before it.",
        reason: "a coverage:ignore-end marker closes the block that a coverage:ignore-start marker opened, and no block is open at this line.",
        fix: "add a coverage:ignore-start marker on its own line before the first line to ignore, or remove this marker.",
      )
    NestedIgnoreStart(source_path, line_number, open_line_number) ->
      ErrorMessage(
        what: "The coverage:ignore-start marker at "
          <> source_location(source_path, line_number)
          <> " is inside the ignored block that starts at line "
          <> int.to_string(open_line_number)
          <> ".",
        reason: "ignored blocks cannot be nested, so each coverage:ignore-start marker needs a coverage:ignore-end marker before the next coverage:ignore-start marker.",
        fix: "add a coverage:ignore-end marker before line "
          <> int.to_string(line_number)
          <> ", or remove one of the two coverage:ignore-start markers.",
      )
    IgnoreFunctionWithoutFunction(source_path, line_number) ->
      ErrorMessage(
        what: "The coverage:ignore-function marker at "
          <> source_location(source_path, line_number)
          <> " is not followed by a complete function.",
        reason: "a coverage:ignore-function marker ignores the whole function after it, but the code after this marker is not a function, or the file ends before the function ends.",
        fix: "put the marker on its own line directly above a function (doc comments and attributes can be between them), or use coverage:ignore-start and coverage:ignore-end for other code.",
      )
    IgnoreLineWithoutCode(source_path, line_number) ->
      ErrorMessage(
        what: "The coverage:ignore marker at "
          <> source_location(source_path, line_number)
          <> " is not followed by a line of code.",
        reason: "a coverage:ignore marker ignores the next line that holds code, but another marker comes before that line, or the file ends first.",
        fix: "put the marker on its own line directly above the line to ignore, or remove it.",
      )
    ExcludeWithoutReason(pattern) ->
      ErrorMessage(
        what: "The exclude pattern \"" <> pattern <> "\" has no reason.",
        reason: "coverage.require_exclusion_reasons() is on, so every exclude pattern must say why its files are left out of coverage.",
        fix: "replace coverage.exclude(...) with coverage.exclude_with_reason(pattern: \""
          <> pattern
          <> "\", reason: \"...\").",
      )
    IgnoreMarkerWithoutReason(source_path, line_number, marker) ->
      ErrorMessage(
        what: "The "
          <> marker
          <> " marker at "
          <> source_location(source_path, line_number)
          <> " has no reason.",
        reason: "coverage.require_exclusion_reasons() is on, so every coverage:ignore marker must say why its lines are left out of coverage.",
        fix: "write the reason after the marker on the same line, for example \""
          <> marker
          <> " debug only\".",
      )
  }
}

fn source_location(source_path: String, line_number: Int) -> String {
  source_path <> ":" <> int.to_string(line_number)
}

fn load_message(module: String, cause: LoadCause, raw: String) -> ErrorMessage {
  let what = "Could not load module " <> module <> "."
  case cause {
    ModuleNotBuilt ->
      ErrorMessage(
        what: what,
        reason: "no compiled .beam file for this module is on the code path ("
          <> raw
          <> ").",
        fix: "run the tests with `gleam test`, which builds every module first. If the module has a compile error, fix it.",
      )
    OnLoadFailed ->
      ErrorMessage(
        what: what,
        reason: "the module's on_load function failed (" <> raw <> ").",
        fix: "run the tests without coverage to see the on_load error, then fix it.",
      )
    BadBeamFile ->
      ErrorMessage(
        what: what,
        reason: "the .beam file is damaged or was built for another Erlang version ("
          <> raw
          <> ").",
        fix: "delete the build directory and run `gleam test` again.",
      )
    EmbeddedMode ->
      ErrorMessage(
        what: what,
        reason: "the BEAM runs in embedded mode, which only loads the modules listed when it starts ("
          <> raw
          <> ").",
        fix: "run the tests in interactive mode (the default), or load the module before coverage starts.",
      )
  }
}

fn instrument_message(
  module: String,
  cause: InstrumentCause,
  raw: String,
) -> ErrorMessage {
  let what = "Could not add line counters to module " <> module <> "."
  case cause {
    NoDebugInfo ->
      ErrorMessage(
        what: what,
        reason: "the .beam file has no debug information, so coverage cannot read the module's code ("
          <> raw
          <> ").",
        fix: "build with `gleam test` or `gleam build`, which keep debug information, and do not strip the .beam files.",
      )
    EncryptedDebugInfo ->
      ErrorMessage(
        what: what,
        reason: "the debug information in the .beam file is encrypted ("
          <> raw
          <> ").",
        fix: "build this module without encrypted debug information.",
      )
    DebugInfoUnreadable ->
      ErrorMessage(
        what: what,
        reason: "the debug information in the .beam file could not be read ("
          <> raw
          <> ").",
        fix: "run `gleam test` again, and do not delete or change .beam files while the tests run.",
      )
    AlreadyInstrumented ->
      ErrorMessage(
        what: what,
        reason: "another tool, such as cover, already gave this module line counters ("
          <> raw
          <> ").",
        fix: "do not run another coverage tool, or call cover yourself, in the same test run.",
      )
    RecompileFailed ->
      ErrorMessage(
        what: what,
        reason: "the Erlang compiler could not compile the module again with line counters ("
          <> raw
          <> ").",
        fix: "run the tests without coverage to check that the module builds. If it does, report the error with the text in brackets.",
      )
    OldCodeInUse ->
      ErrorMessage(
        what: what,
        reason: "a process still runs an older version of this module, and loading the module with line counters would kill that process ("
          <> raw
          <> ").",
        fix: "start coverage before code loads a new version of this module, or stop the processes that run the older version.",
      )
    InstrumentedLoadFailed ->
      ErrorMessage(
        what: what,
        reason: "the module with line counters could not be loaded ("
          <> raw
          <> ").",
        fix: "run the tests without coverage to check that the module loads, then try again.",
      )
  }
}

fn analysis_message(
  module: String,
  cause: AnalysisCause,
  raw: String,
) -> ErrorMessage {
  let what = "Could not read coverage for module " <> module <> "."
  case cause {
    NotInstrumented ->
      ErrorMessage(
        what: what,
        reason: "the module lost its line counters during the run, because it was loaded again or deleted ("
          <> raw
          <> ").",
        fix: "do not load new versions of measured modules, or call cover, from the tests.",
      )
  }
}

/// A file that `coverage.finish` writes: what to call it in a message, the
/// setting that names its path, and the fix when its path is a directory.
type OutputFile {
  OutputFile(name: String, setting: String, directory_fix: String)
}

fn lcov_output() -> OutputFile {
  OutputFile(
    name: "LCOV file",
    setting: "coverage.lcov_path",
    directory_fix: "give a file name with coverage.lcov_path(...), for example build/coverage/lcov.info.",
  )
}

fn json_output() -> OutputFile {
  OutputFile(
    name: "JSON summary",
    setting: "coverage.json_path",
    directory_fix: "give a file name with coverage.json_path(...), for example build/coverage/coverage.json.",
  )
}

fn cobertura_output() -> OutputFile {
  OutputFile(
    name: "Cobertura XML file",
    setting: "coverage.cobertura_path",
    directory_fix: "give a file name with coverage.cobertura_path(...), for example build/coverage/cobertura.xml.",
  )
}

fn markdown_output() -> OutputFile {
  OutputFile(
    name: "Markdown summary",
    setting: "coverage.markdown_path",
    directory_fix: "give a file name with coverage.markdown_path(...), for example build/coverage/coverage.md.",
  )
}

fn html_output() -> OutputFile {
  OutputFile(
    name: "HTML coverage page",
    setting: "coverage.html_path",
    directory_fix: "delete the folder at this path, or give another directory to coverage.html_path(...).",
  )
}

fn html_file_output() -> OutputFile {
  OutputFile(
    name: "combined HTML coverage page",
    setting: "coverage.html_file",
    directory_fix: "give a file name with coverage.html_file(...), for example build/coverage/all.html.",
  )
}

fn write_message(
  output: OutputFile,
  path: String,
  error: FileError,
) -> ErrorMessage {
  let what = "Could not write the " <> output.name <> " \"" <> path <> "\"."
  let raw = file.error_to_string(error)
  case error {
    file.PermissionDenied(_) ->
      ErrorMessage(
        what: what,
        reason: "there is no permission to write to this path (" <> raw <> ").",
        fix: "choose a writable path with "
          <> output.setting
          <> "(...), or fix the folder permissions.",
      )
    file.IsDirectory(_) ->
      ErrorMessage(
        what: what,
        reason: "the path is a directory, not a file (" <> raw <> ").",
        fix: output.directory_fix,
      )
    file.NoSpace(_) ->
      ErrorMessage(
        what: what,
        reason: "the disk is full (" <> raw <> ").",
        fix: "free disk space and run the tests again.",
      )
    file.NotFound(_) ->
      ErrorMessage(
        what: what,
        reason: "a folder in the path does not exist and could not be created ("
          <> raw
          <> ").",
        fix: "check the path given to " <> output.setting <> "(...).",
      )
    file.FileSystemError(_, _) ->
      ErrorMessage(
        what: what,
        reason: "the file system returned an error (" <> raw <> ").",
        fix: "check the path given to "
          <> output.setting
          <> "(...). Every part before the file name must be a folder.",
      )
  }
}

fn below_minimum_message(
  hit: Int,
  total: Int,
  minimum: Float,
  lines_needed: Int,
) -> ErrorMessage {
  ErrorMessage(
    what: "Coverage "
      <> format.percent(hit: hit, total: total)
      <> " is below the minimum "
      <> float.to_string(minimum)
      <> "% (needs "
      <> more_lines(lines_needed - hit)
      <> ").",
    reason: int.to_string(hit)
      <> " of "
      <> int.to_string(total)
      <> " executable lines ran, and the minimum needs "
      <> int.to_string(lines_needed)
      <> ".",
    fix: "add tests for the lines that did not run (coverage.show_missing() lists them), or lower coverage.minimum_percent(...).",
  )
}

fn files_below_minimum_message(
  minimum: Float,
  files: List(FileBelowMinimum),
) -> ErrorMessage {
  ErrorMessage(
    what: "Coverage of "
      <> format.file_count(list.length(files))
      <> " is below the per-file minimum "
      <> float.to_string(minimum)
      <> "%:\n"
      <> string.join(list.map(files, file_below_minimum_line), "\n"),
    reason: "coverage.minimum_percent_per_file(...) needs each measured file to reach the minimum, and too few executable lines ran in these files.",
    fix: "add tests for the lines that did not run in these files (coverage.show_missing() lists them), or lower coverage.minimum_percent_per_file(...).",
  )
}

/// `  src/app/cart.gleam 30.0%, 3 of 10 lines ran (needs 2 more lines)`
fn file_below_minimum_line(file: FileBelowMinimum) -> String {
  let hit = coverage.below_minimum_hit(file)
  let total = coverage.below_minimum_total(file)
  "  "
  <> coverage.below_minimum_source_path(file)
  <> " "
  <> format.percent(hit: hit, total: total)
  <> ", "
  <> int.to_string(hit)
  <> " of "
  <> int.to_string(total)
  <> " lines ran (needs "
  <> more_lines(coverage.below_minimum_lines_needed(file) - hit)
  <> ")"
}

fn more_lines(count: Int) -> String {
  case count {
    1 -> "1 more line"
    _ -> int.to_string(count) <> " more lines"
  }
}

fn describe_module(module_name: String, source_path: String) -> String {
  module_name <> " (" <> source_path <> ")"
}
