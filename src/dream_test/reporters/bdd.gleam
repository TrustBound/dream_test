//// BDD-style test report formatting.
////
//// This module formats `TestResult` values in a hierarchical, spec-like layout
//// that mirrors your `describe` / `it` structure. It’s primarily used by
//// the end-of-run BDD results reporter (`runner.results_reporters([bdd.new()])`),
//// but it’s also useful directly when you want formatted output as a `String`
//// (e.g. snapshot tests) or when you’re formatting results incrementally in a
//// custom runner.

import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/reporters/types as reporter_types
import dream_test/timing
import dream_test/types.{
  type AssertionFailure, type Status, type TestResult, BooleanFailure,
  CollectionFailure, ComparisonFailure, CustomMatcherFailure, EqualityFailure,
  Failed, OptionFailure, Passed, Pending, ResultFailure, SetupFailed, Skipped,
  SnapshotFailure, StringMatchFailure, TimedOut,
}
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/order
import gleam/string

/// The result of formatting a single test result incrementally.
///
/// ## Fields
///
/// - `text`: The output to print for this test result (including any new suite/group headers)
/// - `new_path`: The describe/group path for this result. Pass this as `previous_path`
///   when formatting the next result.
pub type FormatIncrementalResult {
  FormatIncrementalResult(text: String, new_path: List(String))
}

/// The result of formatting a single test result incrementally as separate parts.
///
/// ## Fields
///
/// - `headers`: Any new suite/group lines required for this result
/// - `test_line`: The test line (and any failure details) for this result
/// - `new_path`: The describe/group path for this result. Pass this as `previous_path`
///   when formatting the next result.
pub type FormatIncrementalPartsResult {
  FormatIncrementalPartsResult(
    headers: String,
    test_line: String,
    new_path: List(String),
  )
}

// ============================================================================
// Results reporter builder (end-of-run)
// ============================================================================

/// Create a BDD results reporter.
///
/// This reporter prints at the end of the run, using the traversal-ordered results
/// provided by the runner.
pub fn new() -> reporter_types.ResultsReporter {
  reporter_types.Bdd(reporter_types.BddReporterConfig(
    color: False,
    mode: reporter_types.BddFull,
  ))
}

/// Enable ANSI color output for the BDD report.
pub fn color(
  reporter reporter: reporter_types.ResultsReporter,
) -> reporter_types.ResultsReporter {
  case reporter {
    reporter_types.Bdd(reporter_types.BddReporterConfig(color: _c, mode: mode)) ->
      reporter_types.Bdd(reporter_types.BddReporterConfig(
        color: True,
        mode: mode,
      ))
    other -> other
  }
}

/// Print only the summary line at the end of the run.
pub fn summary_only(
  reporter reporter: reporter_types.ResultsReporter,
) -> reporter_types.ResultsReporter {
  case reporter {
    reporter_types.Bdd(reporter_types.BddReporterConfig(color: color, mode: _)) ->
      reporter_types.Bdd(reporter_types.BddReporterConfig(
        color: color,
        mode: reporter_types.BddSummaryOnly,
      ))
    other -> other
  }
}

/// Print only repeated failures and the summary line at the end of the run.
pub fn failures_only(
  reporter reporter: reporter_types.ResultsReporter,
) -> reporter_types.ResultsReporter {
  case reporter {
    reporter_types.Bdd(reporter_types.BddReporterConfig(color: color, mode: _)) ->
      reporter_types.Bdd(reporter_types.BddReporterConfig(
        color: color,
        mode: reporter_types.BddFailuresOnly,
      ))
    other -> other
  }
}

/// Render the end-of-run BDD output for the given results.
pub fn render(
  config config: reporter_types.BddReporterConfig,
  results results: List(TestResult),
) -> String {
  let reporter_types.BddReporterConfig(color: color, mode: mode) = config
  render_bdd_sections(color, mode, results)
}

fn render_bdd_sections(
  color: Bool,
  mode: reporter_types.BddOutputMode,
  results: List(TestResult),
) -> String {
  let summary = format_summary(color, results)

  case mode {
    reporter_types.BddSummaryOnly -> summary
    reporter_types.BddFailuresOnly -> {
      let failures = filter_failures(results, [])
      let failures_text = format_all_results(color, failures, [], "")
      string.concat([failures_text, "\n", summary])
    }
    reporter_types.BddFull -> {
      let results_text = format_all_results(color, results, [], "")
      let failures = filter_failures(results, [])
      let failures_text = case failures {
        [] -> ""
        _ ->
          "\n"
          <> format_failures_header(color)
          <> "\n"
          <> format_all_results(color, failures, [], "")
      }
      string.concat([results_text, failures_text, "\n", summary])
    }
  }
}

fn filter_failures(
  results: List(TestResult),
  acc_rev: List(TestResult),
) -> List(TestResult) {
  case results {
    [] -> list.reverse(acc_rev)
    [result, ..rest] -> {
      case is_failure_status(result.status) {
        True -> filter_failures(rest, [result, ..acc_rev])
        False -> filter_failures(rest, acc_rev)
      }
    }
  }
}

fn is_failure_status(status: Status) -> Bool {
  case status {
    Failed -> True
    SetupFailed -> True
    TimedOut -> True
    _ -> False
  }
}

fn ansi_wrap(code: String, text: String) -> String {
  string.concat(["\u{1b}[", code, "m", text, "\u{1b}[0m"])
}

fn ansi_dim(text: String) -> String {
  ansi_wrap("2", text)
}

fn ansi_red(text: String) -> String {
  ansi_wrap("31", text)
}

fn ansi_green(text: String) -> String {
  ansi_wrap("32", text)
}

fn ansi_yellow(text: String) -> String {
  ansi_wrap("33", text)
}

fn ansi_cyan(text: String) -> String {
  ansi_wrap("36", text)
}

fn ansi_magenta(text: String) -> String {
  ansi_wrap("35", text)
}

fn ansi_bold(text: String) -> String {
  ansi_wrap("1", text)
}

fn maybe(color: Bool, apply: fn(String) -> String, text: String) -> String {
  case color {
    True -> apply(text)
    False -> text
  }
}

fn format_failures_header(color: Bool) -> String {
  maybe(color, fn(t) { ansi_bold(ansi_red(t)) }, "Failures:")
}

/// Format test results as a BDD-style report string.
///
/// Returns the complete report including:
/// - Hierarchical test results with status markers
/// - Failure details with messages and diffs
/// - Summary line with counts
///
/// Gherkin tests are automatically formatted using the Gherkin reporter style.
///
/// Use this when you need the report as a string (e.g., for testing the
/// reporter itself or writing to a file).
///
/// ## Parameters
///
/// - `results`: The test results to format
///
/// ## Returns
///
/// A single `String` containing the formatted report and trailing summary line.
///
/// ## Example
///
/// ```gleam
/// let report = bdd.format(sample_results())
///
/// report
/// |> should
/// |> match_snapshot("./test/snapshots/bdd_format_report.snap")
/// |> or_fail_with("expected formatted report snapshot match")
/// ```
///
pub fn format(results results: List(TestResult)) -> String {
  // Split results by kind
  let #(gherkin_results, unit_results) = partition_by_kind(results)

  // Format each group with appropriate reporter
  let unit_text = format_unit_results(False, unit_results)
  let gherkin_text = format_gherkin_results(gherkin_results)

  // Combine with single summary
  let summary_text = format_summary(False, results)
  string.concat([unit_text, gherkin_text, "\n", summary_text])
}

fn partition_by_kind(
  results: List(TestResult),
) -> #(List(TestResult), List(TestResult)) {
  list.partition(results, gherkin_reporter.is_gherkin_result)
}

fn format_unit_results(color: Bool, results: List(TestResult)) -> String {
  case results {
    [] -> ""
    _ -> {
      // Sort results by full_name to group tests from the same describe block together.
      // This ensures consistent output regardless of parallel execution order.
      let sorted = list.sort(results, compare_by_full_name)
      format_all_results(color, sorted, [], "")
    }
  }
}

fn compare_by_full_name(a: TestResult, b: TestResult) -> order.Order {
  compare_string_lists(a.full_name, b.full_name)
}

fn compare_string_lists(a: List(String), b: List(String)) -> order.Order {
  case a, b {
    [], [] -> order.Eq
    [], _ -> order.Lt
    _, [] -> order.Gt
    [head_a, ..rest_a], [head_b, ..rest_b] ->
      case string.compare(head_a, head_b) {
        order.Eq -> compare_string_lists(rest_a, rest_b)
        other -> other
      }
  }
}

fn format_gherkin_results(results: List(TestResult)) -> String {
  case results {
    [] -> ""
    _ -> {
      let formatted = gherkin_reporter.format(results)
      // Remove the gherkin reporter's own summary (we'll use combined summary)
      remove_summary_line(formatted)
    }
  }
}

fn remove_summary_line(text: String) -> String {
  // Find and remove the summary line (may have trailing empty lines)
  let lines = string.split(text, "\n")
  let without_summary = remove_gherkin_summary(lines, [])
  string.join(without_summary, "\n")
}

fn remove_gherkin_summary(
  lines: List(String),
  accumulated: List(String),
) -> List(String) {
  case lines {
    [] -> list.reverse(accumulated)
    [line] -> {
      // Check if this is the summary line or trailing empty line
      case string.starts_with(line, "Summary:") || line == "" {
        True -> list.reverse(accumulated)
        False -> list.reverse([line, ..accumulated])
      }
    }
    [line, ..rest] -> {
      // Skip summary lines anywhere in the list
      case string.starts_with(line, "Summary:") {
        True -> remove_gherkin_summary(rest, accumulated)
        False -> remove_gherkin_summary(rest, [line, ..accumulated])
      }
    }
  }
}

/// Print test results using a provided writer function.
///
/// This is the main entry point for most test runs. The writer function
/// receives the formatted report string and can print it, log it, or
/// handle it however needed.
///
/// ## Example
///
/// ```gleam
/// bdd.report([passing_result()], write_bdd_report_to_file)
///
/// use text <- result.try(
///   file.read("test/tmp/bdd_report.txt")
///   |> result.map_error(file.error_to_string),
/// )
///
/// text
/// |> should
/// |> match_snapshot("./test/snapshots/bdd_report_file_output.snap")
/// |> or_fail_with("expected report output snapshot match")
/// ```
///
/// ## Parameters
///
/// - `results`: List of test results from the runner
/// - `write`: Function that handles the formatted output string
///
/// ## Returns
///
/// Returns the input results unchanged, enabling pipeline composition.
///
pub fn report(
  results results: List(TestResult),
  write write: fn(String) -> Nil,
) -> List(TestResult) {
  write(format(results))
  results
}

/// Format a single test result as BDD output, suitable for streaming.
///
/// This is designed to be used with `ReporterEvent.TestFinished` so that BDD
/// output can be printed as tests complete.
///
/// - `previous_path` should be the describe-path (all but the leaf test name)
///   of the previously printed result.
/// - Returns the formatted output for this result, and the updated
///   describe-path to use as `previous_path` for the next call.
///
/// ## Parameters
///
/// - `result`: The test result to format
/// - `previous_path`: The previous describe/group path (from the prior call)
///
/// ## Returns
///
/// A `FormatIncrementalResult` containing the text to print and the new
/// describe/group path to pass as `previous_path` for the next call.
pub fn format_incremental(
  result result: TestResult,
  previous_path previous_path: List(String),
) -> FormatIncrementalResult {
  let text = format_one_result_with_test_indent(False, result, previous_path, 0)
  let new_path = extract_describe_segments(result.full_name)
  FormatIncrementalResult(text: text, new_path: new_path)
}

/// ## Example
///
/// ```gleam
/// use first <- result.try(first_result([passing_result()]))
///
/// let bdd.FormatIncrementalResult(text: _text, new_path: new_path) =
///   bdd.format_incremental(first, [])
///
/// new_path
/// |> should
/// |> be_equal(["Example Suite"])
/// |> or_fail_with("expected new_path to be the describe path")
/// ```
/// Format a single test result as BDD output, allowing an extra indent level
/// for the test line.
///
/// ## Parameters
///
/// - `result`: The test result to format
/// - `previous_path`: The previous describe/group path (from the prior call)
/// - `extra_test_indent`: Additional indentation to apply to the test line
///
/// ## Returns
///
/// A `FormatIncrementalResult` containing the text to print and the new
/// describe/group path to pass as `previous_path` for the next call.
pub fn format_incremental_with_test_indent(
  result result: TestResult,
  previous_path previous_path: List(String),
  extra_test_indent extra_test_indent: Int,
) -> FormatIncrementalResult {
  let text =
    format_one_result_with_test_indent(
      False,
      result,
      previous_path,
      extra_test_indent,
    )
  let new_path = extract_describe_segments(result.full_name)
  FormatIncrementalResult(text: text, new_path: new_path)
}

/// ## Example
///
/// ```gleam
/// let result = passing_result()
/// let bdd.FormatIncrementalResult(text: text, new_path: _new_path) =
///   bdd.format_incremental_with_test_indent(result, [], 0)
///
/// text
/// |> should
/// |> match_snapshot(
///   "./test/snapshots/bdd_format_incremental_with_test_indent.snap",
/// )
/// |> or_fail_with("expected incremental output snapshot match")
/// ```
/// Format a single incremental result as two parts:
/// - `headers`: any new describe/group lines required for this result
/// - `test_line`: the test line (and any failure details)
///
/// This allows callers to insert additional lines (like lifecycle hooks)
/// between headers and the test line while maintaining correct ordering.
///
/// ## Parameters
///
/// - `result`: The test result to format
/// - `previous_path`: The previous describe/group path (from the prior call)
/// - `extra_test_indent`: Additional indentation to apply to the test line
///
/// ## Returns
///
/// A `FormatIncrementalPartsResult` containing:
/// - `headers`: any new describe/group lines required for this result
/// - `test_line`: the test line (and any failure details)
/// - `new_path`: the updated describe/group path to pass as `previous_path` for the next call
pub fn format_incremental_parts_with_test_indent(
  result result: TestResult,
  previous_path previous_path: List(String),
  extra_test_indent extra_test_indent: Int,
) -> FormatIncrementalPartsResult {
  let #(headers, test_line) =
    format_one_result_parts_with_test_indent(
      False,
      result,
      previous_path,
      extra_test_indent,
    )
  let new_path = extract_describe_segments(result.full_name)
  FormatIncrementalPartsResult(
    headers: headers,
    test_line: test_line,
    new_path: new_path,
  )
}

/// ## Example
///
/// ```gleam
/// let result = passing_result()
/// let text =
///   bdd.format_incremental_parts_with_test_indent(result, [], 0)
///   |> incremental_parts_text
///
/// text
/// |> should
/// |> match_snapshot(
///   "./test/snapshots/bdd_format_incremental_parts_with_test_indent.snap",
/// )
/// |> or_fail_with("expected incremental parts snapshot match")
/// ```
/// Format only the trailing summary line (no per-test output).
///
/// ## Parameters
///
/// - `results`: The test results to summarize
///
/// ## Returns
///
/// A single summary line as a `String` (including a trailing newline).
pub fn format_summary_only(results results: List(TestResult)) -> String {
  format_summary(False, results)
}

/// ## Example
///
/// ```gleam
/// let summary = bdd.format_summary_only([passing_result()])
///
/// summary
/// |> should
/// |> match_snapshot("./test/snapshots/bdd_format_summary_only.snap")
/// |> or_fail_with("expected summary snapshot match")
/// ```
fn format_all_results(
  color: Bool,
  results: List(TestResult),
  previous_path: List(String),
  accumulated: String,
) -> String {
  case results {
    [] -> accumulated
    [result, ..rest] -> {
      let formatted = format_one_result(color, result, previous_path)
      let updated = string.concat([accumulated, formatted])
      let new_path = extract_describe_segments(result.full_name)
      format_all_results(color, rest, new_path, updated)
    }
  }
}

fn format_one_result_with_test_indent(
  color: Bool,
  result: TestResult,
  previous_path: List(String),
  extra_test_indent: Int,
) -> String {
  let #(headers, test_line) =
    format_one_result_parts_with_test_indent(
      color,
      result,
      previous_path,
      extra_test_indent,
    )
  string.concat([headers, test_line])
}

fn format_one_result(
  color: Bool,
  result: TestResult,
  previous_path: List(String),
) -> String {
  format_one_result_with_test_indent(color, result, previous_path, 0)
}

fn format_one_result_parts_with_test_indent(
  color: Bool,
  result: TestResult,
  previous_path: List(String),
  extra_test_indent: Int,
) -> #(String, String) {
  let current_path = extract_describe_segments(result.full_name)
  let common_depth = count_common_prefix(previous_path, current_path, 0)
  let new_segments = list.drop(current_path, common_depth)
  let is_gherkin = gherkin_reporter.is_gherkin_result(result)
  let headers =
    format_header_segments_for_kind(
      color,
      new_segments,
      common_depth,
      is_gherkin,
      "",
    )
  let test_line =
    format_test_line_with_indent_for_kind(
      color,
      result,
      extra_test_indent,
      is_gherkin,
    )
  #(headers, test_line)
}

fn format_header_segments_for_kind(
  color: Bool,
  segments: List(String),
  depth: Int,
  is_gherkin: Bool,
  accumulated: String,
) -> String {
  case segments {
    [] -> accumulated
    [segment, ..rest] -> {
      let indent = build_indent(depth)
      let label = case is_gherkin && depth == 0 {
        True -> "Feature: " <> segment
        False -> segment
      }
      let styled = maybe(color, fn(t) { ansi_bold(ansi_cyan(t)) }, label)
      let header = string.concat([indent, styled, "\n"])
      let updated = string.concat([accumulated, header])
      format_header_segments_for_kind(
        color,
        rest,
        depth + 1,
        is_gherkin,
        updated,
      )
    }
  }
}

fn count_common_prefix(
  previous: List(String),
  current: List(String),
  depth: Int,
) -> Int {
  case previous, current {
    [prev_head, ..prev_rest], [curr_head, ..curr_rest] ->
      count_common_prefix_check(
        prev_head,
        curr_head,
        prev_rest,
        curr_rest,
        depth,
      )
    _, _ -> depth
  }
}

fn count_common_prefix_check(
  prev_head: String,
  curr_head: String,
  prev_rest: List(String),
  curr_rest: List(String),
  depth: Int,
) -> Int {
  case prev_head == curr_head {
    True -> count_common_prefix(prev_rest, curr_rest, depth + 1)
    False -> depth
  }
}

fn extract_describe_segments(full_name: List(String)) -> List(String) {
  case list.reverse(full_name) {
    [] -> []
    [_] -> []
    [_, ..rest] -> list.reverse(rest)
  }
}

fn format_test_line_with_indent_for_kind(
  color: Bool,
  result: TestResult,
  extra_indent: Int,
  is_gherkin: Bool,
) -> String {
  let depth = calculate_test_depth(result.full_name)
  let indent = build_indent(depth + extra_indent)
  let marker = status_marker(color, result.status)
  let name = case is_gherkin {
    True -> "Scenario: " <> extract_test_name(result.full_name)
    False -> extract_test_name(result.full_name)
  }
  let duration = format_duration(result.duration_ms)
  let colored_name = case result.status {
    Passed -> name
    Failed -> maybe(color, ansi_red, name)
    SetupFailed -> maybe(color, ansi_red, name)
    TimedOut -> maybe(color, ansi_red, name)
    Skipped -> maybe(color, ansi_yellow, name)
    Pending -> maybe(color, ansi_yellow, name)
  }
  let test_line =
    string.concat([indent, marker, " ", colored_name, duration, "\n"])
  let failure_text = format_failure_details(color, result, depth + extra_indent)
  string.concat([test_line, failure_text])
}

fn format_duration(duration_ms: Int) -> String {
  case duration_ms {
    // Don't show timing for very fast tests (< 1ms)
    ms if ms <= 0 -> ""
    ms -> " (" <> timing.format_duration_ms(ms) <> ")"
  }
}

fn calculate_test_depth(full_name: List(String)) -> Int {
  case full_name {
    [] -> 0
    [_] -> 0
    _ -> list.length(full_name) - 1
  }
}

fn build_indent(level: Int) -> String {
  build_indent_recursive(level, "")
}

fn build_indent_recursive(level: Int, accumulated: String) -> String {
  case level {
    0 -> accumulated
    n -> build_indent_recursive(n - 1, string.concat([accumulated, "  "]))
  }
}

fn extract_test_name(full_name: List(String)) -> String {
  case list.reverse(full_name) {
    [last, ..] -> last
    [] -> ""
  }
}

fn status_marker(color: Bool, status: Status) -> String {
  case status {
    Passed -> maybe(color, ansi_green, "✓")
    Failed -> maybe(color, ansi_red, "✗")
    Skipped -> maybe(color, ansi_yellow, "-")
    Pending -> maybe(color, ansi_yellow, "~")
    TimedOut -> maybe(color, ansi_red, "!")
    SetupFailed -> maybe(color, ansi_red, "⚠")
  }
}

fn format_failure_details(
  color: Bool,
  result: TestResult,
  indent_level: Int,
) -> String {
  case result.status {
    Failed -> format_all_failures(color, result.failures, indent_level, "")
    SetupFailed -> format_all_failures(color, result.failures, indent_level, "")
    TimedOut -> format_all_failures(color, result.failures, indent_level, "")
    _ -> ""
  }
}

fn format_all_failures(
  color: Bool,
  failures: List(AssertionFailure),
  indent_level: Int,
  accumulated: String,
) -> String {
  case failures {
    [] -> accumulated
    [failure, ..rest] -> {
      let formatted = format_one_failure(color, failure, indent_level)
      let updated = string.concat([accumulated, formatted])
      format_all_failures(color, rest, indent_level, updated)
    }
  }
}

fn format_one_failure(
  color: Bool,
  failure: AssertionFailure,
  indent_level: Int,
) -> String {
  let base_indent = build_indent(indent_level)

  let operator_text =
    maybe(color, fn(t) { ansi_bold(ansi_magenta(t)) }, failure.operator)
  let header = string.concat([base_indent, "  ", operator_text, "\n"])
  let message_text = format_failure_message(color, failure.message, base_indent)
  let payload_text = format_failure_payload(color, failure.payload, base_indent)

  string.concat([header, message_text, payload_text])
}

fn format_failure_message(
  color: Bool,
  message: String,
  base_indent: String,
) -> String {
  case message {
    "" -> ""
    _ -> {
      let label = maybe(color, ansi_dim, "    Message: ")
      let msg = maybe(color, ansi_red, message)
      string.concat([base_indent, label, msg, "\n"])
    }
  }
}

fn format_failure_payload(
  color: Bool,
  payload: option.Option(types.FailurePayload),
  base_indent: String,
) -> String {
  case payload {
    Some(BooleanFailure(actual, expected)) -> {
      let expected_text = case expected {
        True -> "True"
        False -> "False"
      }
      let actual_text = case actual {
        True -> "True"
        False -> "False"
      }
      format_expected_actual(color, base_indent, expected_text, actual_text)
    }
    Some(EqualityFailure(actual, expected)) ->
      format_expected_actual(color, base_indent, expected, actual)
    Some(OptionFailure(actual, expected_some)) -> {
      let expected_text = case expected_some {
        True -> "Some(_)"
        False -> "None"
      }
      format_expected_actual(color, base_indent, expected_text, actual)
    }
    Some(ResultFailure(actual, expected_ok)) -> {
      let expected_text = case expected_ok {
        True -> "Ok(_)"
        False -> "Error(_)"
      }
      format_expected_actual(color, base_indent, expected_text, actual)
    }
    Some(CollectionFailure(actual, expected, operation)) -> {
      let op_line =
        base_indent
        <> maybe(color, ansi_dim, "    Operation: ")
        <> maybe(color, ansi_cyan, operation)
        <> "\n"
      op_line <> format_expected_actual(color, base_indent, expected, actual)
    }
    Some(ComparisonFailure(actual, expected, operator)) -> {
      let op_line =
        base_indent
        <> maybe(color, ansi_dim, "    Operator: ")
        <> maybe(color, ansi_cyan, operator)
        <> "\n"
      op_line <> format_expected_actual(color, base_indent, expected, actual)
    }
    Some(StringMatchFailure(actual, pattern, operation)) -> {
      let op_line =
        base_indent
        <> maybe(color, ansi_dim, "    Operation: ")
        <> maybe(color, ansi_cyan, operation)
        <> "\n"
      let pat_line =
        base_indent
        <> maybe(color, ansi_dim, "    Pattern:   ")
        <> maybe(color, ansi_green, pattern)
        <> "\n"
      let actual_line =
        base_indent
        <> maybe(color, ansi_dim, "    Actual:    ")
        <> maybe(color, ansi_red, actual)
        <> "\n"
      op_line <> pat_line <> actual_line
    }
    Some(SnapshotFailure(actual, expected, snapshot_path, is_missing)) ->
      format_snapshot_failure(
        color,
        actual,
        expected,
        snapshot_path,
        is_missing,
        base_indent,
      )
    Some(CustomMatcherFailure(actual, description)) -> {
      let desc_line =
        base_indent
        <> maybe(color, ansi_dim, "    Description: ")
        <> maybe(color, ansi_cyan, description)
        <> "\n"
      let actual_line =
        base_indent
        <> maybe(color, ansi_dim, "    Actual:      ")
        <> maybe(color, ansi_red, actual)
        <> "\n"
      desc_line <> actual_line
    }
    _ -> ""
  }
}

fn format_expected_actual(
  color: Bool,
  base_indent: String,
  expected: String,
  actual: String,
) -> String {
  let expected_label = maybe(color, ansi_dim, "    Expected: ")
  let actual_label = maybe(color, ansi_dim, "    Actual:   ")
  string.concat([
    base_indent,
    expected_label,
    maybe(color, ansi_green, expected),
    "\n",
    base_indent,
    actual_label,
    maybe(color, ansi_red, actual),
    "\n",
  ])
}

fn format_snapshot_failure(
  color: Bool,
  actual: String,
  expected: String,
  snapshot_path: String,
  is_missing: Bool,
  base_indent: String,
) -> String {
  case is_missing {
    True ->
      string.concat([
        base_indent,
        maybe(color, ansi_dim, "    Snapshot missing: "),
        maybe(color, ansi_yellow, snapshot_path),
        "\n",
      ])
    False ->
      string.concat([
        base_indent,
        maybe(color, ansi_dim, "    Snapshot: "),
        maybe(color, ansi_cyan, snapshot_path),
        "\n",
        format_expected_actual(color, base_indent, expected, actual),
      ])
  }
}

fn format_summary(color: Bool, results: List(TestResult)) -> String {
  let total = list.length(results)
  let failed = count_by_status(results, Failed)
  let skipped = count_by_status(results, Skipped)
  let pending = count_by_status(results, Pending)
  let timed_out = count_by_status(results, TimedOut)
  let setup_failed = count_by_status(results, SetupFailed)
  let passed = total - failed - skipped - pending - timed_out - setup_failed
  let total_duration = sum_durations(results, 0)

  string.concat([
    maybe(color, fn(t) { ansi_bold(ansi_cyan(t)) }, "Summary: "),
    maybe(color, ansi_cyan, int.to_string(total)),
    " run, ",
    maybe(color, ansi_red, int.to_string(failed)),
    " failed, ",
    maybe(color, ansi_green, int.to_string(passed)),
    " passed",
    build_summary_suffix(color, skipped, pending, timed_out, setup_failed),
    " in ",
    maybe(color, ansi_cyan, timing.format_duration_ms(total_duration)),
    "\n",
  ])
}

fn sum_durations(results: List(TestResult), total: Int) -> Int {
  case results {
    [] -> total
    [result, ..rest] -> sum_durations(rest, total + result.duration_ms)
  }
}

fn count_by_status(results: List(TestResult), wanted: Status) -> Int {
  count_matching_status(results, wanted, 0)
}

fn count_matching_status(
  results: List(TestResult),
  wanted: Status,
  count: Int,
) -> Int {
  case results {
    [] -> count
    [result, ..rest] -> {
      let next_count = increment_if_matches(result.status, wanted, count)
      count_matching_status(rest, wanted, next_count)
    }
  }
}

fn increment_if_matches(status: Status, wanted: Status, count: Int) -> Int {
  case status == wanted {
    True -> count + 1
    False -> count
  }
}

fn build_summary_suffix(
  color: Bool,
  skipped: Int,
  pending: Int,
  timed_out: Int,
  setup_failed: Int,
) -> String {
  let parts =
    []
    |> add_summary_part_if_nonzero(color, skipped, " skipped", ansi_yellow)
    |> add_summary_part_if_nonzero(color, pending, " pending", ansi_yellow)
    |> add_summary_part_if_nonzero(color, timed_out, " timed out", ansi_red)
    |> add_summary_part_if_nonzero(
      color,
      setup_failed,
      " setup failed",
      ansi_red,
    )

  format_summary_parts(parts)
}

fn format_summary_parts(parts: List(String)) -> String {
  case parts {
    [] -> ""
    _ -> string.concat([", ", string.join(parts, ", ")])
  }
}

fn add_summary_part_if_nonzero(
  parts: List(String),
  color: Bool,
  count: Int,
  label: String,
  paint: fn(String) -> String,
) -> List(String) {
  case count {
    0 -> parts
    _ -> [
      string.concat([paint(int.to_string(count)), maybe(color, ansi_dim, label)]),
      ..parts
    ]
  }
}
