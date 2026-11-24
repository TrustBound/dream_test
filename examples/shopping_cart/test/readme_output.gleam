//// Checks the report that the README of this example shows.
//// `scripts/examples.sh` in the repository root runs it with
//// `gleam run -m readme_output`.
////
//// The test runs the two features of the example with no output, sets the
//// duration of every test to 0, so that the report is the same in every
//// run, renders the report as `bdd.new()` prints it at the end of a run,
//// and compares it with `test/outputs/readme_report.txt`.

import dream_test/file
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/types.{type RunReport, type TestResult, TestResult}
import dream_test/unit.{describe, it}
import features/shopping_cart as shopping_cart_feature
import features/shopping_cart_file as shopping_cart_file_feature
import gleam/list

/// The report that the README shows.
const readme_report_path = "test/outputs/readme_report.txt"

pub fn tests() {
  describe("README output", [
    it("the README shows the report of the two features", fn() {
      // Act
      let report =
        runner.new([
          shopping_cart_feature.tests(),
          shopping_cart_file_feature.tests(),
        ])
        |> runner.silent()
        |> runner.run()
        |> without_durations()
        |> render_as_bdd_new()

      // Assert
      Ok(report)
      |> should
      |> be_equal(file.read(readme_report_path))
      |> or_fail_with("expected the report in " <> readme_report_path)
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

/// The report as `bdd.new()` prints it: with no colour, every test.
fn render_as_bdd_new(report: RunReport) -> String {
  bdd.render(
    config: reporter_types.BddReporterConfig(
      color: False,
      mode: reporter_types.BddFull,
    ),
    report: report,
  )
}

/// The report with the duration of every test set to 0.
fn without_durations(report: RunReport) -> RunReport {
  types.run_report(
    tests: list.map(types.report_tests(report), without_duration),
    hook_failures: types.report_hook_failures(report),
    reporter_crashes: types.report_reporter_crashes(report),
  )
}

fn without_duration(result: TestResult) -> TestResult {
  TestResult(..result, duration_ms: 0)
}
