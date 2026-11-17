//// Gherkin-style report formatting.
////
//// This module formats `TestResult` values with kind `GherkinScenario(_ )` in a
//// Cucumber-like layout (Feature → Scenario), so you can print or persist a
//// human-readable report for BDD runs.
////
//// Most users won’t call this module directly—`dream_test/reporters` wires it
//// in automatically—but it’s useful when you want:
////
//// - a Gherkin report as a `String` (`format`)
//// - the feature and scenario lines without a summary (`format_scenarios`)
//// - to write the report using a custom function (`report`)

import dream_test/timing
import dream_test/types.{
  type AssertionFailure, type Status, type TestResult, EqualityFailure, Failed,
  GherkinScenario, Passed, Pending, SetupFailed, Skipped, TimedOut,
}
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string

// ============================================================================
// Public API
// ============================================================================

/// Format test results as a Gherkin-style report string.
///
/// Returns the complete report including:
/// - Feature name as header
/// - Scenario names with status markers
/// - Summary with scenario counts
///
/// Use this when you need the report as a string.
///
/// ## Example
///
/// ```gleam
/// gherkin_reporter.format(sample_results())
/// |> should
/// |> match_snapshot("./test/snapshots/gherkin_format_report.snap")
/// |> or_fail_with("expected formatted report snapshot match")
/// ```
///
/// ## Parameters
///
/// - `results`: The test results to format
///
/// ## Returns
///
/// The formatted report as a `String`.
pub fn format(results results: List(TestResult)) -> String {
  let summary_text = format_summary(results)
  string.concat([format_scenarios(results), "\n", summary_text])
}

/// Format test results as Gherkin feature and scenario lines, with no
/// summary.
///
/// `format` gives these lines, then an empty line and the summary line.
/// Use `format_scenarios` when you write your own summary, for example in a
/// reporter that shows unit tests and Gherkin scenarios together with one
/// summary for all of them. The BDD reporter does this.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/gherkin as gherkin_reporter
/// import dream_test/types.{GherkinScenario, Passed, TestResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn tests() {
///   describe("Gherkin scenario lines", [
///     it("format_scenarios gives the lines without a summary", fn() {
///       let result =
///         TestResult(
///           name: "Adding items",
///           full_name: ["Shopping Cart", "Adding items"],
///           status: Passed,
///           duration_ms: 0,
///           tags: [],
///           failures: [],
///           kind: GherkinScenario("cart"),
///         )
///
///       gherkin_reporter.format_scenarios([result])
///       |> should
///       |> be_equal("Feature: Shopping Cart\n  Scenario: Adding items ✓\n")
///       |> or_fail_with("expected one feature line and one scenario line")
///     }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `results`: The test results to format
///
/// ## Returns
///
/// The feature and scenario lines as a `String`. Each line ends with `\n`.
/// An empty list gives `""`.
pub fn format_scenarios(results results: List(TestResult)) -> String {
  format_all_results(results, "", "")
}

/// Print test results using a provided writer function.
///
/// This is the main entry point for Gherkin test runs.
///
/// ## Example
///
/// ```gleam
/// let results = runner.new([tests()]) |> runner.run()
/// gherkin_reporter.report(results, io.print)
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

/// Check if a TestResult is from a Gherkin test.
///
/// Useful for filtering or routing results to the appropriate reporter.
///
/// ## Example
///
/// ```gleam
/// gherkin_reporter.is_gherkin_result(gherkin_result())
/// |> should
/// |> be_equal(True)
/// |> or_fail_with("expected True for gherkin results")
/// ```
///
/// ## Parameters
///
/// - `result`: A single `TestResult` to inspect
///
/// ## Returns
///
/// `True` when `result.kind` is `GherkinScenario(_)`, otherwise `False`.
pub fn is_gherkin_result(result result: TestResult) -> Bool {
  case result.kind {
    GherkinScenario(_) -> True
    _ -> False
  }
}

// ============================================================================
// Result Formatting
// ============================================================================

fn format_all_results(
  results: List(TestResult),
  previous_feature: String,
  accumulated: String,
) -> String {
  case results {
    [] -> accumulated
    [result, ..rest] -> {
      let feature_name = extract_feature_name(result.full_name)
      let feature_header =
        format_feature_header_if_new(feature_name, previous_feature)
      let scenario_text = format_scenario(result)
      let updated = string.concat([accumulated, feature_header, scenario_text])
      format_all_results(rest, feature_name, updated)
    }
  }
}

fn extract_feature_name(full_name: List(String)) -> String {
  case full_name {
    [] -> "Unknown Feature"
    [feature, ..] -> feature
  }
}

fn format_feature_header_if_new(current: String, previous: String) -> String {
  case current == previous {
    True -> ""
    False -> string.concat(["Feature: ", current, "\n"])
  }
}

fn format_scenario(result: TestResult) -> String {
  let scenario_name = extract_scenario_name(result.full_name)
  let marker = status_marker(result.status)
  let duration = format_duration(result.duration_ms)
  let scenario_line =
    string.concat(["  Scenario: ", scenario_name, " ", marker, duration, "\n"])
  let failure_text = format_failure_details(result)
  string.concat([scenario_line, failure_text])
}

fn format_duration(duration_ms: Int) -> String {
  case duration_ms {
    // Don't show timing for very fast tests (< 1ms)
    ms if ms <= 0 -> ""
    ms -> " (" <> timing.format_duration_ms(ms) <> ")"
  }
}

fn extract_scenario_name(full_name: List(String)) -> String {
  case list.reverse(full_name) {
    [] -> "Unknown Scenario"
    [name, ..] -> name
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

// ============================================================================
// Failure Formatting
// ============================================================================

fn format_failure_details(result: TestResult) -> String {
  case result.status {
    Failed -> format_all_failures(result.failures, "")
    SetupFailed -> format_all_failures(result.failures, "")
    _ -> ""
  }
}

fn format_all_failures(
  failures: List(AssertionFailure),
  accumulated: String,
) -> String {
  case failures {
    [] -> accumulated
    [failure, ..rest] -> {
      let formatted = format_one_failure(failure)
      let updated = string.concat([accumulated, formatted])
      format_all_failures(rest, updated)
    }
  }
}

fn format_one_failure(failure: AssertionFailure) -> String {
  let header = string.concat(["      ✗ ", failure.operator, "\n"])
  let message_text = format_failure_message(failure.message)
  let payload_text = format_failure_payload(failure.payload)
  string.concat([header, message_text, payload_text])
}

fn format_failure_message(message: String) -> String {
  case message {
    "" -> ""
    _ -> string.concat(["        Message: ", message, "\n"])
  }
}

fn format_failure_payload(
  payload: option.Option(types.FailurePayload),
) -> String {
  case payload {
    Some(EqualityFailure(actual, expected)) ->
      string.concat([
        "        Expected: ",
        expected,
        "\n",
        "        Actual:   ",
        actual,
        "\n",
      ])
    _ -> ""
  }
}

// ============================================================================
// Summary
// ============================================================================

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
    // Each part goes on the front of the list, so the list is in reverse
    // order: setup failed first, skipped last.
    _ -> string.concat([", ", string.join(list.reverse(parts), ", ")])
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
