//// Gherkin-style report formatting.
////
//// This module formats `TestResult` values with kind `GherkinScenario(..)` in a
//// Cucumber-like layout (Feature → Scenario), so you can print or persist a
//// human-readable report for BDD runs.
////
//// Most users won’t call this module directly—`dream_test/reporters` wires it
//// in automatically—but it’s useful when you want:
////
//// - a Gherkin report as a `String` (`format`)
//// - the feature and scenario lines without a summary (`format_scenarios`)
//// - to write the report using a custom function (`report`)

import dream_test/reporters/diff
import dream_test/reporters/hook_failures
import dream_test/reporters/summary
import dream_test/timing
import dream_test/types.{
  type AssertionFailure, type RunReport, type Status, type TestResult,
  EqualityFailure, Failed, GherkinScenario, Passed, Pending, SetupFailed,
  Skipped, SnapshotFailure, StepFailure, TimedOut,
}
import gleam/int
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
/// ### Format a Gherkin report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/gherkin/format.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/gherkin as gherkin_reporter
/// import dream_test/types.{
///   type AssertionResult, type TestResult, GherkinScenario, Passed, TestResult,
/// }
/// import gleam/option.{None, Some}
///
/// pub fn scenario_result() -> TestResult {
///   TestResult(
///     name: "Adding items",
///     groups: ["Shopping Cart"],
///     status: Passed,
///     duration_ms: 0,
///     tags: [],
///     failures: [],
///     kind: GherkinScenario(
///       scenario_id: "cart",
///       feature: Some("Shopping Cart"),
///       rule: None,
///     ),
///   )
/// }
///
/// pub fn report_shows_the_feature_and_scenario() -> Result(
///   AssertionResult,
///   String,
/// ) {
///   gherkin_reporter.format(
///     types.run_report(
///       tests: [scenario_result()],
///       hook_failures: [],
///       reporter_crashes: [],
///     ),
///   )
///   |> should
///   |> be_equal(
///     "Feature: Shopping Cart\n  Scenario: Adding items ✓\n\nSummary: 1 run, 0 failed, 1 passed in 0ms\n",
///   )
///   |> or_fail_with("expected the formatted report")
/// }
/// ```
///
/// ## Parameters
///
/// - `report`: The run report to format: the test results and the
///   hook failures
///
/// ## Returns
///
/// The formatted report as a `String`.
pub fn format(report report: RunReport) -> String {
  let summary_text = summary.format(report)
  let teardown_text = case types.report_hook_failures(report) {
    [] -> ""
    _ -> "\n" <> hook_failures.format(types.report_hook_failures(report))
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
/// The headings come from the result kind, not from the place or the name
/// of a group. A scenario in the group of its Feature
/// (`GherkinScenario(feature: Some(name), ..)`) prints under the heading
/// `Feature: <name>`. Any other result, such as a scenario of
/// `steps.Scenarios` (`feature: None`) or a unit test, prints under
/// its groups joined with ` > `, for example `Shop > Billing`, and under
/// no heading when it has no group. For a scenario inside a Rule
/// (`GherkinScenario(rule: Some(rule), ..)`), the Rule prints as a heading
/// under the first heading, and the scenarios of the Rule indent two more
/// spaces. So a Feature named `Rule: refunds` prints as
/// `Feature: Rule: refunds`.
///
/// `format` gives these lines, then an empty line and the summary line.
/// Use `format_scenarios` when you write your own summary, for example in a
/// reporter that shows unit tests and Gherkin scenarios together with one
/// summary for all of them. The BDD reporter does this.
///
/// ## Example
///
/// ### Format only the scenario lines <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/gherkin/format_scenarios.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/gherkin as gherkin_reporter
/// import dream_test/suite.{type TestSuite}
/// import dream_test/types.{GherkinScenario, Passed, TestResult}
/// import dream_test/unit.{describe, it}
/// import gleam/option.{None, Some}
///
/// pub fn tests() -> TestSuite {
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
///           kind: GherkinScenario(
///             scenario_id: "cart",
///             feature: Some("Shopping Cart"),
///             rule: None,
///           ),
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
/// - `results`: The test results to format, in run order
///
/// ## Returns
///
/// The feature and scenario lines as a `String`. Each line ends with `\n`.
/// An empty list gives `""`.
pub fn format_scenarios(results results: List(TestResult)) -> String {
  format_all_results(results, None, "")
}

/// Print test results using a provided writer function.
///
/// This is the main entry point for Gherkin test runs.
///
/// ## Example
///
/// ### Print a Gherkin report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/gherkin/report.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{succeed}
/// import dream_test/reporters/gherkin as gherkin_reporter
/// import dream_test/runner
/// import dream_test/suite.{type TestSuite}
/// import dream_test/types.{type RunReport}
/// import dream_test/unit.{describe, it}
/// import gleam/io
///
/// pub fn tests() -> TestSuite {
///   describe("Shopping Cart", [
///     it("adds items", fn() { Ok(succeed()) }),
///   ])
/// }
///
/// pub fn main() -> RunReport {
///   let report = runner.new([tests()]) |> runner.run()
///   gherkin_reporter.report(report, io.print)
/// }
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
/// ### Check that a result is a Gherkin scenario <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/gherkin/is_gherkin_result.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/gherkin as gherkin_reporter
/// import dream_test/types.{
///   type AssertionResult, type TestResult, GherkinScenario, Passed, TestResult,
/// }
/// import gleam/option.{None, Some}
///
/// pub fn scenario_result() -> TestResult {
///   TestResult(
///     name: "Adding items",
///     groups: ["Shopping Cart"],
///     status: Passed,
///     duration_ms: 0,
///     tags: [],
///     failures: [],
///     kind: GherkinScenario(
///       scenario_id: "cart",
///       feature: Some("Shopping Cart"),
///       rule: None,
///     ),
///   )
/// }
///
/// pub fn scenario_is_a_gherkin_result() -> Result(AssertionResult, String) {
///   gherkin_reporter.is_gherkin_result(scenario_result())
///   |> should
///   |> be_equal(True)
///   |> or_fail_with("expected True for gherkin results")
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: A single `TestResult` to inspect
///
/// ## Returns
///
/// `True` when `result.kind` is `GherkinScenario(..)`, otherwise `False`.
pub fn is_gherkin_result(result result: TestResult) -> Bool {
  case result.kind {
    GherkinScenario(..) -> True
    _ -> False
  }
}

// ============================================================================
// Result Formatting
// ============================================================================

/// The headings that a scenario line belongs under.
///
/// `title` is the first heading line: `Feature: <name>` for a scenario in
/// the group of its Feature (`GherkinScenario(feature: Some(name), ..)`),
/// else the groups of the result, outside its Rule group, joined with
/// ` > `. It is `None` when there is no such group, so there is nothing to
/// name. `rule` is the name of the Rule group, from the result kind.
type Heading {
  Heading(title: Option(String), rule: Option(String))
}

fn format_all_results(
  results: List(TestResult),
  previous: Option(Heading),
  accumulated: String,
) -> String {
  case results {
    [] -> accumulated
    [result, ..rest] -> {
      let heading = heading_of(result)
      let heading_text = format_heading_if_new(heading, previous)
      let scenario_text = format_scenario(result, heading)
      let updated = string.concat([accumulated, heading_text, scenario_text])
      format_all_results(rest, Some(heading), updated)
    }
  }
}

/// The headings of a result. The Feature and the Rule come from the result
/// kind, never from the position of a group.
fn heading_of(result: TestResult) -> Heading {
  let #(groups, rule) = case result.kind {
    GherkinScenario(rule: Some(rule), ..) -> #(
      list.take(result.groups, list.length(result.groups) - 1),
      Some(rule),
    )
    _ -> #(result.groups, None)
  }
  let title = case result.kind, groups {
    GherkinScenario(feature: Some(feature), ..), _ ->
      Some("Feature: " <> feature)
    _, [] -> None
    _, _ -> Some(string.join(groups, " > "))
  }
  Heading(title: title, rule: rule)
}

fn format_heading_if_new(
  current: Heading,
  previous: Option(Heading),
) -> String {
  case previous {
    Some(previous) if previous == current -> ""
    Some(previous) if previous.title == current.title ->
      format_rule_heading(current)
    _ ->
      string.concat([format_title(current.title), format_rule_heading(current)])
  }
}

fn format_title(title: Option(String)) -> String {
  case title {
    Some(title) -> title <> "\n"
    None -> ""
  }
}

fn format_rule_heading(heading: Heading) -> String {
  case heading.rule {
    Some(rule) -> string.concat([title_indent(heading), rule, "\n"])
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

/// Two spaces under a title line, none when there is no title line.
fn title_indent(heading: Heading) -> String {
  case heading.title {
    Some(_) -> "  "
    None -> ""
  }
}

/// Two more spaces under a Rule heading.
fn scenario_indent(heading: Heading) -> String {
  case heading.rule {
    Some(_) -> title_indent(heading) <> "  "
    None -> title_indent(heading)
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
  let step_text = format_step_line(failure.payload)
  let message_text = format_failure_message(failure.message)
  let payload_text = format_failure_payload(step_cause(failure.payload))
  string.concat([header, step_text, message_text, payload_text])
}

/// The `Step:` line of a failure in a Gherkin step, or `""`.
fn format_step_line(payload: Option(types.FailurePayload)) -> String {
  case payload {
    Some(StepFailure(keyword:, text:, file:, line:, ..)) ->
      string.concat([
        "        Step: ",
        keyword,
        " ",
        text,
        step_place(file, line),
        "\n",
      ])
    _ -> ""
  }
}

/// The place of a step after its text: ` (file:line)`, ` (file)`,
/// ` (line N)`, or `""` when neither is known.
fn step_place(file: Option(String), line: Option(Int)) -> String {
  case file, line {
    Some(file), Some(line) -> " (" <> file <> ":" <> int.to_string(line) <> ")"
    Some(file), None -> " (" <> file <> ")"
    None, Some(line) -> " (line " <> int.to_string(line) <> ")"
    None, None -> ""
  }
}

/// The payload to show under the message: the payload inside a step
/// failure, or the payload itself.
fn step_cause(
  payload: Option(types.FailurePayload),
) -> Option(types.FailurePayload) {
  case payload {
    Some(StepFailure(cause:, ..)) -> cause
    _ -> payload
  }
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
      format_expected_actual(expected, actual)
    Some(SnapshotFailure(snapshot_path:, is_missing: True, ..)) ->
      "        Snapshot missing: " <> snapshot_path <> "\n"
    Some(SnapshotFailure(actual:, expected:, snapshot_path:, is_missing: False)) ->
      "        Snapshot: "
      <> snapshot_path
      <> "\n"
      <> format_expected_actual(expected, actual)
    _ -> ""
  }
}

/// `Expected:` and `Actual:` lines, or a line diff when either text has more
/// than one line.
fn format_expected_actual(expected: String, actual: String) -> String {
  case diff.should_diff(expected: expected, actual: actual) {
    True ->
      diff.format(
        expected: expected,
        actual: actual,
        indent: "        ",
        color: False,
      )
    False ->
      string.concat([
        "        Expected: ",
        expected,
        "\n",
        "        Actual:   ",
        actual,
        "\n",
      ])
  }
}
