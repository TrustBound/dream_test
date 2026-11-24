//// Compares the outputs that the guides show, under `test/outputs/`, with
//// the real reports of the suites in playback mode. The times differ from
//// run to run, so the check leaves them out of both texts.

import dream_test/file
import dream_test/matchers.{be_equal, contain_string, or_fail_with, should}
import dream_test/parallel
import dream_test/reporters/bdd
import dream_test/reporters/types as reporter_types
import dream_test/runner.{type RunBuilder}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}
import envoy
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
        "test/recordings/http/GET_localhost__v1_forecast_oslo_e37e6826285e2b49.json",
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
    it("shows the report of the Forecast suite in playback", fn() {
      runner.new([forecast_tests.tests()])
      |> matches_output("forecast_playback")
    }),
  ])
}

/// Runs the Forecast suite live, as `RECORDER_MODE=passthrough gleam test`
/// does: the requests go to the mock server, and the recorder writes
/// nothing. The variable is the same for the whole BEAM, so this suite runs
/// after the other suites, and gives the variable its old value again.
pub fn live_tests() -> TestSuite {
  describe("The live run in the guides", [
    it("shows the report of the Forecast suite in a live run", fn() {
      let old_mode = envoy.get("RECORDER_MODE")
      envoy.set("RECORDER_MODE", "passthrough")
      let builder = runner.new([forecast_tests.tests()])
      let report = report_text(builder)
      restore_mode(old_mode)
      use expected <- result.try(read_text("test/outputs/forecast_live.txt"))
      report
      |> should
      |> be_equal(without_times(expected))
      |> or_fail_with("the report should match test/outputs/forecast_live.txt")
    }),
  ])
}

fn restore_mode(old_mode: Result(String, Nil)) -> Nil {
  case old_mode {
    Ok(text) -> envoy.set("RECORDER_MODE", text)
    Error(Nil) -> envoy.unset("RECORDER_MODE")
  }
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
  |> be_equal(without_times(expected))
  |> or_fail_with("the report should match test/outputs/" <> name <> ".txt")
}

/// Runs the suites with no output, and gives the report as `bdd.new()`
/// prints it, with no color and with the times left out (see
/// `without_times`).
pub fn report_text(builder: RunBuilder) -> String {
  builder
  |> runner.silent()
  |> runner.run()
  |> render
  |> without_times
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

/// The report with the times left out, so that two runs give the same
/// text: the time of each test, such as ` (12ms)`, goes away, and the time
/// of the summary line, such as `in 31ms`, becomes `in <time>`.
pub fn without_times(report: String) -> String {
  report
  |> string.split("\n")
  |> list.map(line_without_time)
  |> string.join("\n")
}

fn line_without_time(line: String) -> String {
  case string.starts_with(line, "Summary: "), string.split_once(line, " in ") {
    True, Ok(#(counts, _time)) -> counts <> " in <time>"
    _, _ -> without_test_time(line)
  }
}

/// A test line ends with its time in brackets, such as ` (12ms)` or
/// ` (1.2s)`, when the test took 1ms or more.
fn without_test_time(line: String) -> String {
  case string.ends_with(line, ")") {
    False -> line
    True ->
      case string.split_once(string.reverse(line), "( ") {
        Ok(#(reversed_time, reversed_rest)) ->
          case is_time(string.reverse(string.drop_start(reversed_time, 1))) {
            True -> string.reverse(reversed_rest)
            False -> line
          }
        Error(Nil) -> line
      }
  }
}

/// A time as `timing.format_duration_ms` writes it: `12ms`, `1.2s`,
/// `2m 5s` or `1h 3m`.
fn is_time(text: String) -> Bool {
  let starts_with_digit = case string.first(text) {
    Ok(first) -> string.contains("0123456789", first)
    Error(Nil) -> False
  }
  starts_with_digit
  && {
    string.ends_with(text, "ms")
    || string.ends_with(text, "s")
    || string.ends_with(text, "m")
  }
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
