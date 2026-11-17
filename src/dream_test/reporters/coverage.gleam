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
//// When coverage fails, `render_failure` prints a `Coverage failed` block
//// instead. The runner writes it to the error output.
////
//// Percentages round down, so a file shows `100.0%` only when every line ran.
//// A file with no executable lines shows `-`.

import dream_test/coverage.{
  type AnalysisCause, type CoverageConfig, type CoverageError,
  type InstrumentCause, type LoadCause, type StartCause, AlreadyInstrumented,
  BadBeamFile, BelowMinimumPercent, CoverAlreadyRunning, CoverDidNotStart,
  CoverStartFailed, EmbeddedMode, EncryptedDebugInfo, InstrumentedLoadFailed,
  InvalidMinimumPercent, LcovReadFailed, LcovSourceNotFound, LcovWriteFailed,
  MalformedLcov, ModuleNotAnalysed, ModuleNotBuilt, ModuleNotInstrumented,
  ModuleNotLoaded, NoDebugInfo, NoLcovFilesMatched, NoSourceFiles,
  NotInstrumented, OnLoadFailed, SourceDirectoryNotFound,
  SourceDirectoryOutsideSourceRoot, UnknownAnalysisError, UnknownInstrumentError,
}
import dream_test/coverage/report.{
  type CoverageReport, type FileCoverage, type LineCoverage,
}
import dream_test/file.{type FileError}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string

/// How the test run ended, for the last line of a coverage failure.
///
/// - `passed`: tests with status `Passed`
/// - `failed`: tests with status `Failed`, `SetupFailed` or `TimedOut`
/// - `exit_on_failure`: whether the runner exits with status 1 on failure
pub type RunOutcome {
  RunOutcome(passed: Int, failed: Int, exit_on_failure: Bool)
}

type CoverageRow {
  CoverageRow(
    label: String,
    lines: String,
    percent: String,
    missing: List(String),
  )
}

type ColumnWidths {
  ColumnWidths(label: Int, lines: Int, percent: Int)
}

/// The widest the `Missing` column gets before it wraps onto another line.
const missing_column_width = 60

/// Render a coverage report as a table.
///
/// The settings decide two things: `coverage.show_missing` adds the
/// `Missing` column, and the LCOV path (`coverage.lcov_file`) is printed on
/// the last line when there is one.
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
  let show_missing = coverage.shows_missing(config)
  let file_rows = list.map(report.files(coverage_report), file_row)
  let total_row =
    row_from_counts(
      "Total",
      report.total_hit_line_count(coverage_report),
      report.total_executable_line_count(coverage_report),
      [],
    )
  let header_row = header_row(show_missing)
  let rows = list.flatten([[header_row], file_rows, [total_row]])
  let widths =
    list.fold(rows, ColumnWidths(label: 0, lines: 0, percent: 0), widen_columns)

  "\nCoverage\n"
  <> render_rows(rows, widths, show_missing, "")
  <> render_lcov_line(coverage.lcov_file(config))
}

fn header_row(show_missing: Bool) -> CoverageRow {
  let missing = case show_missing {
    True -> ["Missing"]
    False -> []
  }
  CoverageRow(label: "File", lines: "Lines", percent: "Cover", missing: missing)
}

fn file_row(file: FileCoverage) -> CoverageRow {
  row_from_counts(
    report.source_path(file),
    report.hit_line_count(file),
    report.executable_line_count(file),
    wrap_ranges(missing_line_ranges(report.lines(file)), "", []),
  )
}

fn row_from_counts(
  label: String,
  hit: Int,
  total: Int,
  missing: List(String),
) -> CoverageRow {
  CoverageRow(
    label: label,
    lines: int.to_string(hit) <> "/" <> int.to_string(total),
    percent: format_percent(hit, total),
    missing: missing,
  )
}

/// Format `hit / total` as a percent with one decimal place, rounded down,
/// so `100.0%` means every line ran. No executable lines gives `-`.
fn format_percent(hit: Int, total: Int) -> String {
  case total {
    0 -> "-"
    _ -> format_tenths(hit * 1000 / total)
  }
}

fn format_tenths(tenths: Int) -> String {
  int.to_string(tenths / 10) <> "." <> int.to_string(tenths % 10) <> "%"
}

/// The lines that did not run, as ranges: consecutive line numbers merge
/// (`258-260`), a single line stays a number (`245`).
fn missing_line_ranges(lines: List(LineCoverage)) -> List(String) {
  lines
  |> list.filter(line_was_missed)
  |> list.map(line_number)
  |> merge_ranges(None, [])
}

fn line_was_missed(line: LineCoverage) -> Bool {
  line.calls == 0
}

fn line_number(line: LineCoverage) -> Int {
  line.line
}

fn merge_ranges(
  numbers: List(Int),
  open_range: option.Option(#(Int, Int)),
  ranges_reversed: List(String),
) -> List(String) {
  case numbers, open_range {
    [], None -> list.reverse(ranges_reversed)
    [], Some(range) -> list.reverse([range_text(range), ..ranges_reversed])
    [number, ..rest], None -> merge_ranges(rest, Some(#(number, number)), [])
    [number, ..rest], Some(#(first, last)) if number == last + 1 ->
      merge_ranges(rest, Some(#(first, number)), ranges_reversed)
    [number, ..rest], Some(range) ->
      merge_ranges(rest, Some(#(number, number)), [
        range_text(range),
        ..ranges_reversed
      ])
  }
}

fn range_text(range: #(Int, Int)) -> String {
  case range {
    #(first, last) if first == last -> int.to_string(first)
    #(first, last) -> int.to_string(first) <> "-" <> int.to_string(last)
  }
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
  ColumnWidths(
    label: int.max(widths.label, string.length(row.label)),
    lines: int.max(widths.lines, string.length(row.lines)),
    percent: int.max(widths.percent, string.length(row.percent)),
  )
}

fn render_rows(
  rows: List(CoverageRow),
  widths: ColumnWidths,
  show_missing: Bool,
  rendered: String,
) -> String {
  case rows {
    [] -> rendered
    [row, ..rest] ->
      render_rows(
        rest,
        widths,
        show_missing,
        rendered <> render_row(row, widths, show_missing),
      )
  }
}

fn render_row(
  row: CoverageRow,
  widths: ColumnWidths,
  show_missing: Bool,
) -> String {
  let counts =
    string.pad_end(row.label, widths.label + 2, " ")
    <> string.pad_end(row.lines, widths.lines + 2, " ")
  case show_missing, row.missing {
    False, _ -> counts <> row.percent <> "\n"
    True, [] -> counts <> row.percent <> "\n"
    True, [first, ..rest] ->
      counts
      <> string.pad_end(row.percent, widths.percent + 2, " ")
      <> first
      <> "\n"
      <> render_continuation_lines(
        rest,
        string.repeat(" ", widths.label + widths.lines + widths.percent + 6),
        "",
      )
  }
}

fn render_continuation_lines(
  lines: List(String),
  indent: String,
  rendered: String,
) -> String {
  case lines {
    [] -> rendered
    [line, ..rest] ->
      render_continuation_lines(
        rest,
        indent,
        rendered <> indent <> line <> "\n",
      )
  }
}

fn render_lcov_line(lcov_path: option.Option(String)) -> String {
  case lcov_path {
    None -> ""
    Some(path) -> "LCOV: " <> path <> "\n"
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
///   outcome: RunOutcome(passed: 3, failed: 0, exit_on_failure: True),
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

type ExitReason {
  ExitReason(alone: String, with_failed_tests: String)
}

fn exit_reason(error: CoverageError) -> ExitReason {
  case error {
    BelowMinimumPercent(..) ->
      ExitReason(
        alone: "coverage is below the minimum",
        with_failed_tests: "tests failed and coverage is below the minimum",
      )
    _ ->
      ExitReason(
        alone: "coverage was requested and did not complete",
        with_failed_tests: "tests failed and coverage did not complete",
      )
  }
}

fn outcome_line(outcome: RunOutcome, reason: ExitReason) -> String {
  let tests = tests_line(outcome.passed, outcome.failed)
  case outcome.exit_on_failure, outcome.failed {
    True, 0 -> tests <> " Exit status 1, because " <> reason.alone <> "."
    True, _ ->
      tests <> " Exit status 1, because " <> reason.with_failed_tests <> "."
    False, _ ->
      tests
      <> " The exit status is not changed, because exit_on_failure is off."
  }
}

fn tests_line(passed: Int, failed: Int) -> String {
  case failed {
    0 -> "Tests: " <> int.to_string(passed) <> " passed."
    _ ->
      "Tests: "
      <> int.to_string(passed)
      <> " passed, "
      <> int.to_string(failed)
      <> " failed."
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
        fix: "run `gleam test` from the project root, or set the path with coverage.source_directory(...).",
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
    CoverStartFailed(cause, raw) -> start_message(cause, raw)
    ModuleNotLoaded(module_name, source_path, cause, raw) ->
      load_message(describe_module(module_name, source_path), cause, raw)
    ModuleNotInstrumented(module_name, source_path, cause, raw) ->
      instrument_message(describe_module(module_name, source_path), cause, raw)
    ModuleNotAnalysed(module_name, source_path, cause, raw) ->
      analysis_message(describe_module(module_name, source_path), cause, raw)
    LcovWriteFailed(path, error) -> lcov_message(path, error)
    InvalidMinimumPercent(value) ->
      ErrorMessage(
        what: "The coverage minimum "
          <> float.to_string(value)
          <> " is not a percent.",
        reason: "coverage.minimum_percent(...) takes a value from 0.0 to 100.0.",
        fix: "pass a value from 0.0 to 100.0, for example coverage.minimum_percent(80.0).",
      )
    BelowMinimumPercent(hit, total, minimum, lines_needed) ->
      below_minimum_message(hit, total, minimum, lines_needed)
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
        fix: "write SF paths relative to the project root, or delete LCOV files left from an older version of the code.",
      )
  }
}

fn start_message(cause: StartCause, raw: String) -> ErrorMessage {
  let what = "Could not start the BEAM cover tool."
  case cause {
    CoverAlreadyRunning ->
      ErrorMessage(
        what: what,
        reason: "cover is already running, so another coverage run owns it ("
          <> raw
          <> ").",
        fix: "turn coverage on once with runner.coverage, and do not start cover from a test or another tool in the same run.",
      )
    CoverDidNotStart ->
      ErrorMessage(
        what: what,
        reason: "cover returned an error (" <> raw <> ").",
        fix: "check that the Erlang tools application is installed; some minimal Erlang packages leave it out.",
      )
  }
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
  let what = "Could not instrument module " <> module <> " for coverage."
  case cause {
    NoDebugInfo ->
      ErrorMessage(
        what: what,
        reason: "the .beam file has no debug information, so cover cannot read the module's code ("
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
    AlreadyInstrumented ->
      ErrorMessage(
        what: what,
        reason: "another tool already instrumented this module from source ("
          <> raw
          <> ").",
        fix: "do not run another coverage tool, or call cover yourself, in the same test run.",
      )
    InstrumentedLoadFailed ->
      ErrorMessage(
        what: what,
        reason: "cover instrumented the module but could not load the result ("
          <> raw
          <> ").",
        fix: "run the tests without coverage to check that the module loads, then try again.",
      )
    UnknownInstrumentError ->
      ErrorMessage(
        what: what,
        reason: "cover returned an error (" <> raw <> ").",
        fix: "run the tests without coverage to check that the module builds and loads.",
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
        reason: "the module was no longer instrumented at the end of the run, so something stopped or reset cover during the tests ("
          <> raw
          <> ").",
        fix: "do not call cover:stop, cover:reset or cover:compile from tests.",
      )
    UnknownAnalysisError ->
      ErrorMessage(
        what: what,
        reason: "cover returned an error (" <> raw <> ").",
        fix: "run the tests again. If the error repeats, report it with the text in brackets.",
      )
  }
}

fn lcov_message(path: String, error: FileError) -> ErrorMessage {
  let what = "Could not write the LCOV file \"" <> path <> "\"."
  let raw = file.error_to_string(error)
  case error {
    file.PermissionDenied(_) ->
      ErrorMessage(
        what: what,
        reason: "there is no permission to write to this path (" <> raw <> ").",
        fix: "choose a writable path with coverage.lcov_path(...), or fix the folder permissions.",
      )
    file.IsDirectory(_) ->
      ErrorMessage(
        what: what,
        reason: "the path is a directory, not a file (" <> raw <> ").",
        fix: "give a file name with coverage.lcov_path(...), for example build/coverage/lcov.info.",
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
        fix: "check the path given to coverage.lcov_path(...).",
      )
    file.FileSystemError(_, _) ->
      ErrorMessage(
        what: what,
        reason: "the file system returned an error (" <> raw <> ").",
        fix: "check the path given to coverage.lcov_path(...). Every part before the file name must be a folder.",
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
      <> format_percent(hit, total)
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

fn more_lines(count: Int) -> String {
  case count {
    1 -> "1 more line"
    _ -> int.to_string(count) <> " more lines"
  }
}

fn describe_module(module_name: String, source_path: String) -> String {
  module_name <> " (" <> source_path <> ")"
}
