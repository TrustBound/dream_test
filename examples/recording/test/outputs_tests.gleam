//// Compares the outputs that the guides show, under `test/outputs/`, with
//// the real reports of the suites in playback mode.

import dream_test/file
import dream_test/matchers.{be_equal, contain_string, or_fail_with, should}
import dream_test/parallel
import dream_test/reporters/bdd
import dream_test/reporters/types as reporter_types
import dream_test/runner.{type RunBuilder}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport, TestResult}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/result
import gleam/string
import recorded_http/alerts_tests
import recorded_http/forecast_tests
import recorded_http/miss_tests as http_miss_tests
import recorded_queries/miss_tests as query_miss_tests
import recorded_queries/tasks_tests
import simplifile

pub fn tests() -> TestSuite {
  describe("The outputs in the guides", [
    it("shows the report of the HTTP suites", fn() {
      runner.new([forecast_tests.tests(), alerts_tests.tests()])
      |> matches_output("http_playback")
    }),
    it("shows the report of a request with no recording", fn() {
      runner.new([http_miss_tests.tests()])
      |> matches_output("http_miss")
    }),
    it("shows the report of the task suite", fn() {
      runner.new([])
      |> runner.add_suites_with_config(one_at_a_time(), [tasks_tests.tests()])
      |> matches_output("queries_playback")
    }),
    it("shows the report of a query with no recording", fn() {
      runner.new([query_miss_tests.tests()])
      |> matches_output("queries_miss")
    }),
    it("keeps the token out of the HTTP recordings", fn() {
      use text <- result.try(all_http_recordings())
      #(
        string.contains(string.lowercase(text), "authorization"),
        string.contains(text, "test-token"),
      )
      |> should
      |> be_equal(#(False, False))
      |> or_fail_with("no HTTP recording should hold the token")
    }),
    it("keeps the share tokens out of the query recording", fn() {
      file.read("test/recordings/queries/tasks.json")
      |> result.map_error(file.error_to_string)
      |> result.unwrap("")
      |> should
      |> contain_string("{\"tuple\":[\"[hidden]\"]}")
      |> or_fail_with("the recording should hold [hidden] for the token")
    }),
    it("shows the recording of the Oslo forecast", fn() {
      // The recorder writes no newline at the end of the file
      use recording <- result.try(read_text(
        "test/recordings/http/GET_localhost__v1_forecast_oslo_e37e68_e41681.json",
      ))
      use expected <- result.try(read_text(
        "test/outputs/http_oslo_recording.txt",
      ))
      recording
      |> string.append("\n")
      |> should
      |> be_equal(expected)
      |> or_fail_with("the output should be the recording file")
    }),
  ])
}

fn read_text(path: String) -> Result(String, String) {
  file.read(path) |> result.map_error(file.error_to_string)
}

fn one_at_a_time() -> parallel.ParallelConfig {
  parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 10_000)
}

/// Compares the report of the suites with `test/outputs/<name>.txt`.
fn matches_output(builder: RunBuilder, name: String) {
  let report = report_text(builder)
  use expected <- result.try(
    file.read("test/outputs/" <> name <> ".txt")
    |> result.map_error(file.error_to_string),
  )
  report
  |> should
  |> be_equal(expected)
  |> or_fail_with("the report should match test/outputs/" <> name <> ".txt")
}

/// Runs the suites with no output, and gives the report as `bdd.new()`
/// prints it, with no color and with every duration set to 0.
pub fn report_text(builder: RunBuilder) -> String {
  builder
  |> runner.silent()
  |> runner.run()
  |> without_durations
  |> render
}

fn render(report: RunReport) -> String {
  bdd.render(
    config: reporter_types.BddReporterConfig(
      color: False,
      mode: reporter_types.BddFull,
    ),
    report: report,
  )
}

fn without_durations(report: RunReport) -> RunReport {
  types.run_report(
    tests: list.map(types.report_tests(report), fn(result) {
      TestResult(..result, duration_ms: 0)
    }),
    hook_failures: types.report_hook_failures(report),
    reporter_crashes: types.report_reporter_crashes(report),
  )
}

fn all_http_recordings() -> Result(String, String) {
  let directory = "test/recordings/http"
  use names <- result.try(
    simplifile.read_directory(directory)
    |> result.map_error(simplifile.describe_error),
  )
  names
  |> list.try_map(fn(name) {
    simplifile.read(directory <> "/" <> name)
    |> result.map_error(simplifile.describe_error)
  })
  |> result.map(string.concat)
}
