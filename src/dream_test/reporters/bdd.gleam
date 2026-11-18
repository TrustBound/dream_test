//// BDD-style test report formatting.
////
//// This module formats `TestResult` values in a hierarchical, spec-like layout
//// that mirrors your `describe` / `it` structure. It’s primarily used by
//// the end-of-run BDD results reporter (`runner.results_reporters([bdd.new()])`),
//// but it’s also useful directly when you want formatted output as a `String`
//// (e.g. snapshot tests) or when you’re formatting results incrementally in a
//// custom runner.

import dream_test/reporters/ansi
import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/reporters/summary
import dream_test/reporters/teardown
import dream_test/reporters/types as reporter_types
import dream_test/timing
import dream_test/types.{
  type AssertionFailure, type RunReport, type Status, type TestResult,
  BooleanFailure, CollectionFailure, ComparisonFailure, CustomMatcherFailure,
  EqualityFailure, Failed, OptionFailure, Passed, Pending, ResultFailure,
  SetupFailed, Skipped, SnapshotFailure, StringMatchFailure, TimedOut,
}
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

/// Render the end-of-run BDD output for a run report.
///
/// The output has the test results, then the failures (full mode), then a
/// `Tear-down failures:` section when a tear-down hook failed (full and
/// failures-only modes), then the summary line.
pub fn render(
  config config: reporter_types.BddReporterConfig,
  report report: RunReport,
) -> String {
  let reporter_types.BddReporterConfig(color: color, mode: mode) = config
  render_bdd_sections(color, mode, report)
}

fn render_bdd_sections(
  color: Bool,
  mode: reporter_types.BddOutputMode,
  report: RunReport,
) -> String {
  let summary = format_summary(color, report)
  let results = types.report_tests(report)
  let teardown_text = format_teardown_section(color, report)

  case mode {
    reporter_types.BddSummaryOnly -> summary
    reporter_types.BddFailuresOnly -> {
      let failures = filter_failures(results, [])
      let failures_text = format_all_results(color, failures, [], "")
      string.concat([failures_text, teardown_text, "\n", summary])
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
      string.concat([results_text, failures_text, teardown_text, "\n", summary])
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
      case types.is_failure(result.status) {
        True -> filter_failures(rest, [result, ..acc_rev])
        False -> filter_failures(rest, acc_rev)
      }
    }
  }
}

fn format_summary(color: Bool, report: RunReport) -> String {
  case color {
    True -> summary.format_in_color(report)
    False -> summary.format(report)
  }
}

/// The tear-down section with a blank line before it, or `""` when no
/// tear-down hook failed.
fn format_teardown_section(color: Bool, report: RunReport) -> String {
  case types.report_teardown_failures(report), color {
    [], _ -> ""
    _, True ->
      "\n" <> teardown.format_in_color(types.report_teardown_failures(report))
    _, False -> "\n" <> teardown.format(types.report_teardown_failures(report))
  }
}

fn format_failures_header(color: Bool) -> String {
  ansi.apply_if(color, ansi.bold, ansi.apply_if(color, ansi.red, "Failures:"))
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
/// - `report`: The run report to format: the test results and the
///   tear-down failures
///
/// ## Returns
///
/// A single `String` containing the formatted report and trailing summary line.
///
/// ## Example
///
/// ```gleam
/// let report = bdd.format(sample_report())
///
/// report
/// |> should
/// |> match_snapshot("./test/snapshots/bdd_format_report.snap")
/// |> or_fail_with("expected formatted report snapshot match")
/// ```
///
pub fn format(report report: RunReport) -> String {
  // Split results by kind
  let #(gherkin_results, unit_results) =
    partition_by_kind(types.report_tests(report))

  // Format each group with appropriate reporter
  let unit_text = format_unit_results(False, unit_results)
  let gherkin_text = gherkin_reporter.format_scenarios(gherkin_results)

  // Combine with single summary
  let summary_text = summary.format(report)
  let teardown_text = format_teardown_section(False, report)
  string.concat([unit_text, gherkin_text, teardown_text, "\n", summary_text])
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
  compare_string_lists(
    types.full_name(a.groups, a.name),
    types.full_name(b.groups, b.name),
  )
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
/// - `report`: The run report from `runner.run`
/// - `write`: Function that handles the formatted output string
///
/// ## Returns
///
/// Returns the input report unchanged, enabling pipeline composition.
///
pub fn report(
  report report: RunReport,
  write write: fn(String) -> Nil,
) -> RunReport {
  write(format(report))
  report
}

/// Format a single test result as BDD output, suitable for streaming.
///
/// Call it with each `TestResult` as the test finishes, so that BDD output
/// can be printed as tests complete.
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
  let new_path = result.groups
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
  let new_path = result.groups
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
  let new_path = result.groups
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
/// This gives the same line as `summary.format` from
/// `dream_test/reporters/summary`.
///
/// ## Parameters
///
/// - `report`: The run report to summarize
///
/// ## Returns
///
/// A single summary line as a `String` (including a trailing newline).
///
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
pub fn format_summary_only(report report: RunReport) -> String {
  summary.format(report)
}

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
      let new_path = result.groups
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
  let current_path = result.groups
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
      let styled =
        ansi.apply_if(color, ansi.bold, ansi.apply_if(color, ansi.cyan, label))
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

fn format_test_line_with_indent_for_kind(
  color: Bool,
  result: TestResult,
  extra_indent: Int,
  is_gherkin: Bool,
) -> String {
  let depth = list.length(result.groups)
  let indent = build_indent(depth + extra_indent)
  let marker = status_marker(color, result.status)
  let name = case is_gherkin {
    True -> "Scenario: " <> result.name
    False -> result.name
  }
  let duration = format_duration(result.duration_ms)
  let colored_name = case result.status {
    Passed -> name
    Failed -> ansi.apply_if(color, ansi.red, name)
    SetupFailed -> ansi.apply_if(color, ansi.red, name)
    TimedOut -> ansi.apply_if(color, ansi.red, name)
    Skipped -> ansi.apply_if(color, ansi.yellow, name)
    Pending -> ansi.apply_if(color, ansi.yellow, name)
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

fn build_indent(level: Int) -> String {
  build_indent_recursive(level, "")
}

fn build_indent_recursive(level: Int, accumulated: String) -> String {
  case level {
    0 -> accumulated
    n -> build_indent_recursive(n - 1, string.concat([accumulated, "  "]))
  }
}

fn status_marker(color: Bool, status: Status) -> String {
  case status {
    Passed -> ansi.apply_if(color, ansi.green, "✓")
    Failed -> ansi.apply_if(color, ansi.red, "✗")
    Skipped -> ansi.apply_if(color, ansi.yellow, "-")
    Pending -> ansi.apply_if(color, ansi.yellow, "~")
    TimedOut -> ansi.apply_if(color, ansi.red, "!")
    SetupFailed -> ansi.apply_if(color, ansi.red, "⚠")
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
    ansi.apply_if(
      color,
      ansi.bold,
      ansi.apply_if(color, ansi.magenta, failure.operator),
    )
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
      let label = ansi.apply_if(color, ansi.dim, "    Message: ")
      let msg = ansi.apply_if(color, ansi.red, message)
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
        <> ansi.apply_if(color, ansi.dim, "    Operation: ")
        <> ansi.apply_if(color, ansi.cyan, operation)
        <> "\n"
      op_line <> format_expected_actual(color, base_indent, expected, actual)
    }
    Some(ComparisonFailure(actual, expected, operator)) -> {
      let op_line =
        base_indent
        <> ansi.apply_if(color, ansi.dim, "    Operator: ")
        <> ansi.apply_if(color, ansi.cyan, operator)
        <> "\n"
      op_line <> format_expected_actual(color, base_indent, expected, actual)
    }
    Some(StringMatchFailure(actual, pattern, operation)) -> {
      let op_line =
        base_indent
        <> ansi.apply_if(color, ansi.dim, "    Operation: ")
        <> ansi.apply_if(color, ansi.cyan, operation)
        <> "\n"
      let pat_line =
        base_indent
        <> ansi.apply_if(color, ansi.dim, "    Pattern:   ")
        <> ansi.apply_if(color, ansi.green, pattern)
        <> "\n"
      let actual_line =
        base_indent
        <> ansi.apply_if(color, ansi.dim, "    Actual:    ")
        <> ansi.apply_if(color, ansi.red, actual)
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
        <> ansi.apply_if(color, ansi.dim, "    Description: ")
        <> ansi.apply_if(color, ansi.cyan, description)
        <> "\n"
      let actual_line =
        base_indent
        <> ansi.apply_if(color, ansi.dim, "    Actual:      ")
        <> ansi.apply_if(color, ansi.red, actual)
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
  let expected_label = ansi.apply_if(color, ansi.dim, "    Expected: ")
  let actual_label = ansi.apply_if(color, ansi.dim, "    Actual:   ")
  string.concat([
    base_indent,
    expected_label,
    ansi.apply_if(color, ansi.green, expected),
    "\n",
    base_indent,
    actual_label,
    ansi.apply_if(color, ansi.red, actual),
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
        ansi.apply_if(color, ansi.dim, "    Snapshot missing: "),
        ansi.apply_if(color, ansi.yellow, snapshot_path),
        "\n",
      ])
    False ->
      string.concat([
        base_indent,
        ansi.apply_if(color, ansi.dim, "    Snapshot: "),
        ansi.apply_if(color, ansi.cyan, snapshot_path),
        "\n",
        format_expected_actual(color, base_indent, expected, actual),
      ])
  }
}
