//// Gherkin-style test reporter for dream_test.
////
//// This reporter formats Gherkin test results in a Cucumber-like format
//// that mirrors the Given/When/Then structure of your scenarios.
////
//// ## Example Output
////
//// ```text
//// Feature: Shopping Cart
////   Scenario: Adding items ✓
////     Given I have an empty cart
////     When I add 5 items
////     Then I should have 5 items
////
////   Scenario: Removing items ✗
////     Given I have 10 items
////     When I remove 3 items
////     Then I should have 7 items
////       ✗ equal
////         Message: Item count mismatch
////         Expected: 7
////         Actual:   10
////
//// 2 scenarios (1 passed, 1 failed)
//// ```
////
//// ## Usage
////
//// ```gleam
//// import dream_test/gherkin/feature
//// import dream_test/runner
//// import dream_test/reporter/gherkin as gherkin_reporter
//// import gleam/io
////
//// pub fn main() {
////   my_feature_suite()
////   |> runner.run_suite()
////   |> gherkin_reporter.report(io.print)
//// }
//// ```
////
//// ## Status Markers
////
//// | Status      | Marker | Meaning                        |
//// |-------------|--------|--------------------------------|
//// | Passed      | ✓      | All steps succeeded            |
//// | Failed      | ✗      | One or more steps failed       |
//// | Skipped     | -      | Scenario was skipped           |
//// | Pending     | ~      | Scenario is a placeholder      |
//// | TimedOut    | !      | Scenario exceeded timeout      |
//// | SetupFailed | ⚠      | A setup hook failed            |

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
/// let report_string = format(results)
/// file.write("cucumber-results.txt", report_string)
/// ```
///
pub fn format(results: List(TestResult)) -> String {
  let formatted_results = format_all_results(results, "", "")
  let summary_text = format_summary(results)
  string.concat([formatted_results, "\n", summary_text])
}

/// Print test results using a provided writer function.
///
/// This is the main entry point for Gherkin test runs.
///
/// ## Example
///
/// ```gleam
/// results |> report(io.print)
/// ```
///
/// ## Parameters
///
/// - `results` - List of test results from the runner
/// - `write` - Function that handles the formatted output string
///
/// ## Returns
///
/// Returns the input results unchanged, enabling pipeline composition.
///
pub fn report(
  results: List(TestResult),
  write: fn(String) -> Nil,
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
/// let gherkin_results = list.filter(results, is_gherkin_result)
/// let unit_results = list.filter(results, fn(r) { !is_gherkin_result(r) })
/// ```
///
pub fn is_gherkin_result(result: TestResult) -> Bool {
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
  let passed = count_by_status(results, Passed)
  let failed = count_by_status(results, Failed)
  let skipped = count_by_status(results, Skipped)
  let pending = count_by_status(results, Pending)
  let timed_out = count_by_status(results, TimedOut)
  let setup_failed = count_by_status(results, SetupFailed)
  let total_duration = sum_durations(results, 0)

  let scenario_word = case total {
    1 -> "scenario"
    _ -> "scenarios"
  }

  let details =
    build_summary_details(
      passed,
      failed,
      skipped,
      pending,
      timed_out,
      setup_failed,
    )

  string.concat([
    int.to_string(total),
    " ",
    scenario_word,
    " (",
    details,
    ") in ",
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

fn build_summary_details(
  passed: Int,
  failed: Int,
  skipped: Int,
  pending: Int,
  timed_out: Int,
  setup_failed: Int,
) -> String {
  let parts =
    []
    |> add_if_nonzero(passed, "passed")
    |> add_if_nonzero(failed, "failed")
    |> add_if_nonzero(skipped, "skipped")
    |> add_if_nonzero(pending, "pending")
    |> add_if_nonzero(timed_out, "timed out")
    |> add_if_nonzero(setup_failed, "setup failed")
    |> list.reverse()

  string.join(parts, ", ")
}

fn add_if_nonzero(
  parts: List(String),
  count: Int,
  label: String,
) -> List(String) {
  case count {
    0 -> parts
    _ -> [int.to_string(count) <> " " <> label, ..parts]
  }
}

fn count_by_status(results: List(TestResult), wanted: Status) -> Int {
  list.fold(results, 0, fn(count, result) {
    case result.status == wanted {
      True -> count + 1
      False -> count
    }
  })
}
