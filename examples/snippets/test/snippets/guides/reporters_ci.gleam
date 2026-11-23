import dream_test/file
import dream_test/reporters/bdd
import dream_test/reporters/json
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/types.{type AssertionFailure, type RunReport, type TestResult}
import gleam/list
import gleam/string
import snippets/guides/reporters_shop

/// Where the JSON report goes.
pub const json_path = "build/test-report.json"

pub fn main() {
  runner.new([reporters_shop.shop_tests()])
  |> runner.results_reporters([
    bdd.new() |> bdd.failures_only(),
    reporter_types.Custom(github_annotations),
    reporter_types.Custom(write_json),
  ])
  |> runner.exit_on_failure()
  |> runner.run()
}

/// Formats each failed test as a GitHub Actions error annotation, one
/// line for each test.
pub fn github_annotations(report: RunReport) -> String {
  types.report_tests(report)
  |> list.filter(is_failed)
  |> list.map(annotation)
  |> string.concat
}

fn is_failed(result: TestResult) -> Bool {
  types.is_failure(result.status)
}

fn annotation(result: TestResult) -> String {
  let name = string.join(types.full_name(result.groups, result.name), " > ")
  let messages = string.join(list.map(result.failures, message), "; ")
  "::error title=" <> name <> "::" <> messages <> "\n"
}

fn message(failure: AssertionFailure) -> String {
  failure.message
}

/// Writes the JSON report to a file, and says where it went.
pub fn write_json(report: RunReport) -> String {
  case file.write(json_path, json.format(report)) {
    Ok(Nil) -> "JSON report: " <> json_path <> "\n"
    Error(error) -> "No JSON report: " <> file.error_to_string(error) <> "\n"
  }
}
