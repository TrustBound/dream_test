//// JSON test reporter for dream_test.
////
//// This reporter outputs test results as JSON for CI/CD integration,
//// test aggregation, and tooling.
////
//// The JSON object includes:
////
//// - `version`: schema version
//// - `timestamp_ms`: when the report was created
//// - `duration_ms`: total duration (sum of test durations)
//// - `system`: `os`, `otp_version`, `gleam_version`
//// - `summary`: counts by status (`total`, `passed`, `failed`, `skipped`,
////   `pending`, `timed_out`, `setup_failed`), and `teardown_failed`, the
////   number of tear-down hooks that failed
//// - `tests`: per-test details (name, full_name, status, duration_ms, tags, kind, failures)
//// - `teardown_failures`: one object for each tear-down hook that failed,
////   in the order that the hooks ran: `hook` (`"after_each_test"`,
////   `"after_each"`, `"after_all"`, `"after_each_suite"` or
////   `"after_all_suites"`), `scope` (a list of names: the full test name
////   for `after_each` and `after_each_test`, the group path for `after_all`,
////   the suite name for `after_each_suite`, `[]` for `after_all_suites`)
////   and `message`
////
//// The schema version is `"2.0"`. Version `"1.0"` had no `teardown_failed`
//// count and no `teardown_failures` list: a failed tear-down hook was a
//// test with a name such as `<after_all>` in `tests`.
////
//// ## Usage
////
//// ```gleam
//// import dream_test/matchers.{succeed}
//// import dream_test/reporters/json
//// import dream_test/reporters/progress
//// import dream_test/runner
//// import dream_test/unit.{describe, it}
////
//// pub fn tests() {
////   describe("JSON Reporter", [
////     it("outputs JSON format", fn() {
////       // The json reporter prints machine-readable JSON at the end of the run.
////       Ok(succeed())
////     }),
////     it("includes test metadata", fn() {
////       // JSON output includes name, full_name, status, duration, tags
////       Ok(succeed())
////     }),
////   ])
//// }
////
//// pub fn main() {
////   runner.new([tests()])
////   |> runner.progress_reporter(progress.new())
////   |> runner.results_reporters([json.new()])
////   |> runner.exit_on_failure()
////   |> runner.run()
//// }
//// ```

import dream_test/reporters/summary
import dream_test/reporters/types as reporter_types
import dream_test/types.{
  type AssertionFailure, type FailurePayload, type RunReport, type Status,
  type TeardownFailure, type TestKind, type TestResult, BooleanFailure,
  CollectionFailure, ComparisonFailure, CustomMatcherFailure, EqualityFailure,
  Failed, GherkinScenario, Integration, OptionFailure, Passed, Pending,
  ResultFailure, SetupFailed, Skipped, SnapshotFailure, StringMatchFailure,
  TimedOut, Unit,
}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// ============================================================================
// Public API
// ============================================================================

/// Create a JSON results reporter (printed at the end of the run).
pub fn new() -> reporter_types.ResultsReporter {
  reporter_types.Json(reporter_types.JsonReporterConfig(pretty: False))
}

/// Enable pretty-printed JSON output.
pub fn pretty(
  reporter reporter: reporter_types.ResultsReporter,
) -> reporter_types.ResultsReporter {
  case reporter {
    reporter_types.Json(_config) ->
      reporter_types.Json(reporter_types.JsonReporterConfig(pretty: True))
    other -> other
  }
}

/// Render JSON output for a completed run.
pub fn render(
  config config: reporter_types.JsonReporterConfig,
  report report: RunReport,
) -> String {
  let reporter_types.JsonReporterConfig(pretty: pretty) = config
  case pretty {
    True -> format_pretty(report)
    False -> format(report)
  }
}

/// Format test results as a compact JSON string.
///
/// Returns a single-line JSON string suitable for machine parsing.
///
/// ## Parameters
///
/// - `report`: The run report to encode into the JSON report
///
/// ## Returns
///
/// A compact (single-line) JSON string.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{succeed}
/// import dream_test/reporters/json
/// import dream_test/runner
/// import dream_test/unit.{describe, it}
///
/// fn example_suite() {
///   describe("Example Suite", [
///     it("passes", fn() { Ok(succeed()) }),
///   ])
/// }
///
/// pub fn main() {
///   let report = runner.new([example_suite()]) |> runner.run()
///   json.format(report)
/// }
/// ```
///
pub fn format(report report: RunReport) -> String {
  build_report_json(report)
  |> json.to_string
}

/// Format test results as pretty-printed JSON.
///
/// Returns an indented, human-readable JSON string with 2-space indentation.
///
/// ## Parameters
///
/// - `report`: The run report to encode into the JSON report
///
/// ## Returns
///
/// A pretty-printed JSON string with 2-space indentation.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{succeed}
/// import dream_test/reporters/json
/// import dream_test/runner
/// import dream_test/unit.{describe, it}
///
/// fn example_suite() {
///   describe("Example Suite", [
///     it("passes", fn() { Ok(succeed()) }),
///   ])
/// }
///
/// pub fn main() {
///   let report = runner.new([example_suite()]) |> runner.run()
///   json.format_pretty(report)
/// }
/// ```
///
pub fn format_pretty(report report: RunReport) -> String {
  build_report_json(report)
  |> json.to_string
  |> prettify_json
}

/// Print test results as JSON using a provided writer function.
///
/// This is the main entry point for JSON reporting. The writer function
/// receives the JSON string and can print it, log it, or write it to a file.
///
/// ## Parameters
///
/// - `report`: The run report to encode and write
/// - `write`: Output sink for the JSON string (for example `io.print`)
///
/// ## Returns
///
/// Returns the input `report` unchanged, enabling pipeline composition.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{succeed}
/// import dream_test/reporters/json
/// import dream_test/runner
/// import dream_test/unit.{describe, it}
/// import gleam/io
///
/// fn example_suite() {
///   describe("Example Suite", [
///     it("passes", fn() { Ok(succeed()) }),
///   ])
/// }
///
/// pub fn main() {
///   let report = runner.new([example_suite()]) |> runner.run()
///   report |> json.report(io.print)
/// }
/// ```
pub fn report(
  report report: RunReport,
  write write: fn(String) -> Nil,
) -> RunReport {
  write(format(report))
  report
}

/// Print test results as pretty-printed JSON using a provided writer function.
///
/// Same as `report` but with indented, human-readable output.
///
/// ## Parameters
///
/// - `report`: The run report to encode and write
/// - `write`: Output sink for the JSON string (for example `io.print`)
///
/// ## Returns
///
/// Returns the input `report` unchanged, enabling pipeline composition.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{succeed}
/// import dream_test/reporters/json
/// import dream_test/runner
/// import dream_test/unit.{describe, it}
/// import gleam/io
///
/// fn example_suite() {
///   describe("Example Suite", [
///     it("passes", fn() { Ok(succeed()) }),
///   ])
/// }
///
/// pub fn main() {
///   let report = runner.new([example_suite()]) |> runner.run()
///   report |> json.report_pretty(io.print)
/// }
/// ```
///
pub fn report_pretty(
  report report: RunReport,
  write write: fn(String) -> Nil,
) -> RunReport {
  write(format_pretty(report))
  report
}

// ============================================================================
// JSON Building
// ============================================================================

fn build_report_json(report: RunReport) -> Json {
  let counts = summary.count(report)

  json.object([
    #("version", json.string("2.0")),
    #("timestamp_ms", json.int(get_timestamp_ms())),
    #("duration_ms", json.int(counts.duration_ms)),
    #("system", build_system_json()),
    #("summary", build_summary_json(counts)),
    #("tests", json.array(types.report_tests(report), build_test_json)),
    #(
      "teardown_failures",
      json.array(
        types.report_teardown_failures(report),
        build_teardown_failure_json,
      ),
    ),
  ])
}

fn build_system_json() -> Json {
  json.object([
    #("os", json.string(get_os())),
    #("otp_version", json.string(get_otp_version())),
    #("gleam_version", json.string(get_gleam_version())),
  ])
}

fn build_summary_json(counts: summary.Counts) -> Json {
  json.object([
    #("total", json.int(counts.run)),
    #("passed", json.int(counts.passed)),
    #("failed", json.int(counts.failed)),
    #("skipped", json.int(counts.skipped)),
    #("pending", json.int(counts.pending)),
    #("timed_out", json.int(counts.timed_out)),
    #("setup_failed", json.int(counts.setup_failed)),
    #("teardown_failed", json.int(counts.teardown_failed)),
  ])
}

fn build_teardown_failure_json(failure: TeardownFailure) -> Json {
  json.object([
    #("hook", json.string(types.teardown_hook_name(failure.hook))),
    #("scope", json.array(failure.scope, json.string)),
    #("message", json.string(failure.message)),
  ])
}

fn build_test_json(result: TestResult) -> Json {
  json.object([
    #("name", json.string(result.name)),
    #(
      "full_name",
      json.array(types.full_name(result.groups, result.name), json.string),
    ),
    #("status", json.string(status_to_string(result.status))),
    #("duration_ms", json.int(result.duration_ms)),
    #("tags", json.array(result.tags, json.string)),
    #("kind", json.string(kind_to_string(result.kind))),
    #("failures", json.array(result.failures, build_failure_json)),
  ])
}

fn build_failure_json(failure: AssertionFailure) -> Json {
  let base_fields = [
    #("operator", json.string(failure.operator)),
    #("message", json.string(failure.message)),
  ]

  let payload_fields = build_payload_fields(failure.payload)
  json.object(list.append(base_fields, payload_fields))
}

fn build_payload_fields(
  payload: Option(FailurePayload),
) -> List(#(String, Json)) {
  case payload {
    None -> []
    Some(EqualityFailure(actual, expected)) -> [
      #("expected", json.string(expected)),
      #("actual", json.string(actual)),
    ]
    Some(BooleanFailure(actual, expected)) -> [
      #("expected", json.bool(expected)),
      #("actual", json.bool(actual)),
    ]
    Some(OptionFailure(actual, expected_some)) -> [
      #("expected_some", json.bool(expected_some)),
      #("actual", json.string(actual)),
    ]
    Some(ResultFailure(actual, expected_ok)) -> [
      #("expected_ok", json.bool(expected_ok)),
      #("actual", json.string(actual)),
    ]
    Some(CollectionFailure(actual, expected, operation)) -> [
      #("expected", json.string(expected)),
      #("actual", json.string(actual)),
      #("operation", json.string(operation)),
    ]
    Some(ComparisonFailure(actual, expected, operator)) -> [
      #("expected", json.string(expected)),
      #("actual", json.string(actual)),
      #("comparison_operator", json.string(operator)),
    ]
    Some(StringMatchFailure(actual, pattern, operation)) -> [
      #("pattern", json.string(pattern)),
      #("actual", json.string(actual)),
      #("operation", json.string(operation)),
    ]
    Some(SnapshotFailure(actual, expected, snapshot_path, is_missing)) -> [
      #("expected", json.string(expected)),
      #("actual", json.string(actual)),
      #("snapshot_path", json.string(snapshot_path)),
      #("is_missing", json.bool(is_missing)),
    ]
    Some(CustomMatcherFailure(actual, description)) -> [
      #("actual", json.string(actual)),
      #("description", json.string(description)),
    ]
  }
}

// ============================================================================
// Helpers
// ============================================================================

fn status_to_string(status: Status) -> String {
  case status {
    Passed -> "passed"
    Failed -> "failed"
    Skipped -> "skipped"
    Pending -> "pending"
    TimedOut -> "timed_out"
    SetupFailed -> "setup_failed"
  }
}

fn kind_to_string(kind: TestKind) -> String {
  case kind {
    Unit -> "unit"
    Integration -> "integration"
    GherkinScenario(id) -> "gherkin:" <> id
  }
}

// ============================================================================
// JSON Pretty Printing
// ============================================================================

fn prettify_json(input: String) -> String {
  prettify_chars(string.to_graphemes(input), 0, False, "")
}

fn prettify_chars(
  chars: List(String),
  indent: Int,
  in_string: Bool,
  acc: String,
) -> String {
  case chars {
    [] -> acc
    ["\\", escaped, ..rest] if in_string ->
      prettify_chars(rest, indent, True, acc <> "\\" <> escaped)
    ["\"", ..rest] -> prettify_chars(rest, indent, !in_string, acc <> "\"")
    [char, ..rest] if in_string ->
      prettify_chars(rest, indent, True, acc <> char)
    ["{", ..rest] -> {
      let new_indent = indent + 2
      prettify_chars(
        rest,
        new_indent,
        False,
        acc <> "{\n" <> spaces(new_indent),
      )
    }
    ["}", ..rest] -> {
      let new_indent = indent - 2
      prettify_chars(
        rest,
        new_indent,
        False,
        acc <> "\n" <> spaces(new_indent) <> "}",
      )
    }
    ["[", "]", ..rest] -> prettify_chars(rest, indent, False, acc <> "[]")
    ["[", ..rest] -> {
      let new_indent = indent + 2
      prettify_chars(
        rest,
        new_indent,
        False,
        acc <> "[\n" <> spaces(new_indent),
      )
    }
    ["]", ..rest] -> {
      let new_indent = indent - 2
      prettify_chars(
        rest,
        new_indent,
        False,
        acc <> "\n" <> spaces(new_indent) <> "]",
      )
    }
    [",", ..rest] ->
      prettify_chars(rest, indent, False, acc <> ",\n" <> spaces(indent))
    [":", ..rest] -> prettify_chars(rest, indent, False, acc <> ": ")
    [char, ..rest] -> prettify_chars(rest, indent, False, acc <> char)
  }
}

fn spaces(count: Int) -> String {
  string.repeat(" ", count)
}

// ============================================================================
// FFI
// ============================================================================

@external(erlang, "dream_test_reporter_json_ffi", "get_os")
fn get_os() -> String

@external(erlang, "dream_test_reporter_json_ffi", "get_otp_version")
fn get_otp_version() -> String

@external(erlang, "dream_test_reporter_json_ffi", "get_gleam_version")
fn get_gleam_version() -> String

@external(erlang, "dream_test_reporter_json_ffi", "get_timestamp_ms")
fn get_timestamp_ms() -> Int
