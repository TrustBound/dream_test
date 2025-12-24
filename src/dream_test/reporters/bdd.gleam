//// BDD-style test report formatting.
////
//// This module formats `TestResult` values in a hierarchical, spec-like layout
//// that mirrors your `describe` / `it` structure. It’s primarily used by
//// `dream_test/reporters` (the reporter constructors), but it’s also useful
//// directly when you want the formatted output as a `String` or when you’re
//// streaming results as they complete.

import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/timing
import dream_test/types.{
  type AssertionFailure, type Status, type TestResult, EqualityFailure, Failed,
  Passed, Pending, SetupFailed, Skipped, SnapshotFailure, TimedOut,
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
  let unit_text = format_unit_results(unit_results)
  let gherkin_text = format_gherkin_results(gherkin_results)

  // Combine with single summary
  let summary_text = format_summary(results)
  string.concat([unit_text, gherkin_text, "\n", summary_text])
}

fn partition_by_kind(
  results: List(TestResult),
) -> #(List(TestResult), List(TestResult)) {
  list.partition(results, gherkin_reporter.is_gherkin_result)
}

fn format_unit_results(results: List(TestResult)) -> String {
  case results {
    [] -> ""
    _ -> {
      // Sort results by full_name to group tests from the same describe block together.
      // This ensures consistent output regardless of parallel execution order.
      let sorted = list.sort(results, compare_by_full_name)
      format_all_results(sorted, [], "")
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
  let text = format_one_result_with_test_indent(result, previous_path, 0)
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
    format_one_result_with_test_indent(result, previous_path, extra_test_indent)
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
  format_summary(results)
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
  results: List(TestResult),
  previous_path: List(String),
  accumulated: String,
) -> String {
  case results {
    [] -> accumulated
    [result, ..rest] -> {
      let formatted = format_one_result(result, previous_path)
      let updated = string.concat([accumulated, formatted])
      let new_path = extract_describe_segments(result.full_name)
      format_all_results(rest, new_path, updated)
    }
  }
}

fn format_one_result_with_test_indent(
  result: TestResult,
  previous_path: List(String),
  extra_test_indent: Int,
) -> String {
  let #(headers, test_line) =
    format_one_result_parts_with_test_indent(
      result,
      previous_path,
      extra_test_indent,
    )
  string.concat([headers, test_line])
}

fn format_one_result(result: TestResult, previous_path: List(String)) -> String {
  format_one_result_with_test_indent(result, previous_path, 0)
}

fn format_one_result_parts_with_test_indent(
  result: TestResult,
  previous_path: List(String),
  extra_test_indent: Int,
) -> #(String, String) {
  let current_path = extract_describe_segments(result.full_name)
  let common_depth = count_common_prefix(previous_path, current_path, 0)
  let new_segments = list.drop(current_path, common_depth)
  let headers = format_header_segments(new_segments, common_depth, "")
  let test_line = format_test_line_with_indent(result, extra_test_indent)
  #(headers, test_line)
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

fn format_header_segments(
  segments: List(String),
  depth: Int,
  accumulated: String,
) -> String {
  case segments {
    [] -> accumulated
    [segment, ..rest] -> {
      let indent = build_indent(depth)
      let header = string.concat([indent, segment, "\n"])
      let updated = string.concat([accumulated, header])
      format_header_segments(rest, depth + 1, updated)
    }
  }
}

fn format_test_line_with_indent(result: TestResult, extra_indent: Int) -> String {
  let depth = calculate_test_depth(result.full_name)
  let indent = build_indent(depth + extra_indent)
  let marker = status_marker(result.status)
  let name = extract_test_name(result.full_name)
  let duration = format_duration(result.duration_ms)
  let test_line = string.concat([indent, marker, " ", name, duration, "\n"])
  let failure_text = format_failure_details(result, depth + extra_indent)
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

fn status_marker(status: Status) -> String {
  case status {
    Passed -> "✓"
    Failed -> "✗"
    Skipped -> "-"
    Pending -> "~"
    TimedOut -> "!"
    SetupFailed -> "⚠"
  }
}

fn format_failure_details(result: TestResult, indent_level: Int) -> String {
  case result.status {
    Failed -> format_all_failures(result.failures, indent_level, "")
    SetupFailed -> format_all_failures(result.failures, indent_level, "")
    _ -> ""
  }
}

fn format_all_failures(
  failures: List(AssertionFailure),
  indent_level: Int,
  accumulated: String,
) -> String {
  case failures {
    [] -> accumulated
    [failure, ..rest] -> {
      let formatted = format_one_failure(failure, indent_level)
      let updated = string.concat([accumulated, formatted])
      format_all_failures(rest, indent_level, updated)
    }
  }
}

fn format_one_failure(failure: AssertionFailure, indent_level: Int) -> String {
  let base_indent = build_indent(indent_level)

  let header = string.concat([base_indent, "  ", failure.operator, "\n"])
  let message_text = format_failure_message(failure.message, base_indent)
  let payload_text = format_failure_payload(failure.payload, base_indent)

  string.concat([header, message_text, payload_text])
}

fn format_failure_message(message: String, base_indent: String) -> String {
  case message {
    "" -> ""
    _ -> string.concat([base_indent, "    Message: ", message, "\n"])
  }
}

fn format_failure_payload(
  payload: option.Option(types.FailurePayload),
  base_indent: String,
) -> String {
  case payload {
    Some(EqualityFailure(actual, expected)) ->
      string.concat([
        base_indent,
        "    Expected: ",
        expected,
        "\n",
        base_indent,
        "    Actual:   ",
        actual,
        "\n",
      ])
    Some(SnapshotFailure(actual, expected, snapshot_path, is_missing)) ->
      format_snapshot_failure(
        actual,
        expected,
        snapshot_path,
        is_missing,
        base_indent,
      )
    _ -> ""
  }
}

fn format_snapshot_failure(
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
        "    Snapshot missing: ",
        snapshot_path,
        "\n",
      ])
    False ->
      string.concat([
        base_indent,
        "    Snapshot: ",
        snapshot_path,
        "\n",
        base_indent,
        "    Expected: ",
        expected,
        "\n",
        base_indent,
        "    Actual:   ",
        actual,
        "\n",
      ])
  }
}

fn format_summary(results: List(TestResult)) -> String {
  let total = list.length(results)
  let failed = count_by_status(results, Failed)
  let skipped = count_by_status(results, Skipped)
  let pending = count_by_status(results, Pending)
  let timed_out = count_by_status(results, TimedOut)
  let setup_failed = count_by_status(results, SetupFailed)
  let passed = total - failed - skipped - pending - timed_out - setup_failed
  let total_duration = sum_durations(results, 0)

  string.concat([
    "Summary: ",
    int.to_string(total),
    " run, ",
    int.to_string(failed),
    " failed, ",
    int.to_string(passed),
    " passed",
    build_summary_suffix(skipped, pending, timed_out, setup_failed),
    " in ",
    timing.format_duration_ms(total_duration),
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
  skipped: Int,
  pending: Int,
  timed_out: Int,
  setup_failed: Int,
) -> String {
  let parts =
    []
    |> add_summary_part_if_nonzero(skipped, " skipped")
    |> add_summary_part_if_nonzero(pending, " pending")
    |> add_summary_part_if_nonzero(timed_out, " timed out")
    |> add_summary_part_if_nonzero(setup_failed, " setup failed")

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
  count: Int,
  label: String,
) -> List(String) {
  case count {
    0 -> parts
    _ -> [string.concat([int.to_string(count), label]), ..parts]
  }
}
