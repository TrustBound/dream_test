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

import dream_test/reporters/summary
import dream_test/reporters/teardown
import dream_test/timing
import dream_test/types.{
  type AssertionFailure, type RunReport, type Status, type TestResult,
  EqualityFailure, Failed, GherkinScenario, Passed, Pending, SetupFailed,
  Skipped, TimedOut,
}
import gleam/list
import gleam/option.{type Option, None, Some}
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
/// gherkin_reporter.format(sample_report())
/// |> should
/// |> match_snapshot("./test/snapshots/gherkin_format_report.snap")
/// |> or_fail_with("expected formatted report snapshot match")
/// ```
///
/// ## Parameters
///
/// - `report`: The run report to format: the test results and the
///   tear-down failures
///
/// ## Returns
///
/// The formatted report as a `String`.
pub fn format(report report: RunReport) -> String {
  let summary_text = summary.format(report)
  let teardown_text = case types.report_teardown_failures(report) {
    [] -> ""
    _ -> "\n" <> teardown.format(report)
  }
  string.concat([
    format_scenarios(types.report_tests(report)),
    teardown_text,
    "\n",
    summary_text,
  ])
}

/// Format test results as Gherkin feature and scenario lines, with no
/// summary.
///
/// The feature is the last group of a result that is not a Rule group. A
/// Rule group (`Rule: <name>`, made by `gherkin/feature`) prints as a heading
/// under its feature, and the scenarios of the Rule indent two more spaces.
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
///           groups: ["Shopping Cart"],
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
/// - `report`: The run report to format: the test results and the
///   tear-down failures
///
/// ## Returns
///
/// The feature and scenario lines as a `String`. Each line ends with `\n`.
/// An empty list gives `""`.
pub fn format_scenarios(results results: List(TestResult)) -> String {
  format_all_results(results, Heading(feature: "", rule: None), "")
}

/// Print test results using a provided writer function.
///
/// This is the main entry point for Gherkin test runs.
///
/// ## Example
///
/// ```gleam
/// let report = runner.new([tests()]) |> runner.run()
/// gherkin_reporter.report(report, io.print)
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

/// The headings that a scenario line belongs under. `rule` is the name of the
/// `Rule: <name>` group that `gherkin/feature` makes for a Rule.
type Heading {
  Heading(feature: String, rule: Option(String))
}

fn format_all_results(
  results: List(TestResult),
  previous: Heading,
  accumulated: String,
) -> String {
  case results {
    [] -> accumulated
    [result, ..rest] -> {
      let heading = heading_of(result.groups)
      let heading_text = format_heading_if_new(heading, previous)
      let scenario_text = format_scenario(result, heading)
      let updated = string.concat([accumulated, heading_text, scenario_text])
      format_all_results(rest, heading, updated)
    }
  }
}

/// The feature is the last group that is not a Rule group. Discovery puts
/// the suite name before the feature name, so the first group is not always
/// the feature.
fn heading_of(groups: List(String)) -> Heading {
  heading_from_newest(list.reverse(groups))
}

fn heading_from_newest(groups_newest_first: List(String)) -> Heading {
  case groups_newest_first {
    [] -> Heading(feature: unknown_feature, rule: None)
    [last, ..rest] ->
      heading_with_last(last, rest, string.starts_with(last, "Rule:"))
  }
}

fn heading_with_last(
  last: String,
  rest: List(String),
  last_is_rule: Bool,
) -> Heading {
  case last_is_rule, rest {
    False, _ -> Heading(feature: last, rule: None)
    True, [feature, ..] -> Heading(feature: feature, rule: Some(last))
    True, [] -> Heading(feature: unknown_feature, rule: Some(last))
  }
}

const unknown_feature = "Unknown Feature"

fn format_heading_if_new(current: Heading, previous: Heading) -> String {
  case current.feature == previous.feature, current.rule == previous.rule {
    True, True -> ""
    True, False -> format_rule_heading(current.rule)
    False, _ ->
      string.concat([
        "Feature: ",
        current.feature,
        "\n",
        format_rule_heading(current.rule),
      ])
  }
}

fn format_rule_heading(rule: Option(String)) -> String {
  case rule {
    Some(rule) -> string.concat(["  ", rule, "\n"])
    None -> ""
  }
}

fn format_scenario(result: TestResult, heading: Heading) -> String {
  let scenario_name = result.name
  let marker = status_marker(result.status)
  let duration = format_duration(result.duration_ms)
  let scenario_line =
    string.concat([
      scenario_indent(heading),
      "Scenario: ",
      scenario_name,
      " ",
      marker,
      duration,
      "\n",
    ])
  let failure_text = format_failure_details(result)
  string.concat([scenario_line, failure_text])
}

fn scenario_indent(heading: Heading) -> String {
  case heading.rule {
    Some(_) -> "    "
    None -> "  "
  }
}

fn format_duration(duration_ms: Int) -> String {
  case duration_ms {
    // Don't show timing for very fast tests (< 1ms)
    ms if ms <= 0 -> ""
    ms -> " (" <> timing.format_duration_ms(ms) <> ")"
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
    TimedOut -> format_all_failures(result.failures, "")
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
