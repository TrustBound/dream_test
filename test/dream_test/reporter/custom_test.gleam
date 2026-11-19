//// Black-box tests of the custom results reporter,
//// `reporter_types.Custom(render)`.

import dream_test/child_timeout.{with_child_timeout}
import dream_test/coverage_runner_mains
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/json
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/sandbox
import dream_test/suite
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/string

@external(erlang, "dream_test_coverage_test_ffi", "run_main_in_new_vm")
fn run_main_in_new_vm(module: String, function: String) -> #(Int, String)

@external(erlang, "dream_test_reporter_test_ffi", "crash_render_with_long_reason")
fn crash_render_with_long_reason(report: types.RunReport) -> String

pub fn tests() {
  describe("dream_test/reporters/types Custom", [
    it("writes the custom report of a failing run", fn() {
      run_and_record([failing_suite()], [
        reporter_types.Custom(coverage_runner_mains.custom_report),
      ])
      |> should
      |> be_equal(["Custom report: 1 passed, 1 failed\n"])
      |> or_fail_with("expected the custom report of one pass and one fail")
    }),

    it("writes the custom report of a passing run", fn() {
      run_and_record([passing_suite()], [
        reporter_types.Custom(coverage_runner_mains.custom_report),
      ])
      |> should
      |> be_equal(["Custom report: 1 passed, 0 failed\n"])
      |> or_fail_with("expected the custom report of one pass")
    }),

    it("writes each report in list order with the BDD and JSON reports", fn() {
      run_and_record([passing_suite()], [
        reporter_types.Custom(first_report),
        bdd.new() |> bdd.summary_only(),
        json.new(),
        reporter_types.Custom(coverage_runner_mains.custom_report),
      ])
      |> list.map(report_kind)
      |> should
      |> be_equal([
        "first report\n",
        "bdd",
        "json",
        "Custom report: 1 passed, 0 failed\n",
      ])
      |> or_fail_with("expected the four reports in list order")
    }),

    it("writes a named error for a crashed reporter and runs the next", fn() {
      run_and_record_streams([passing_suite()], [
        reporter_types.Custom(coverage_runner_mains.crash_render),
        reporter_types.Custom(coverage_runner_mains.custom_report),
      ])
      |> should
      |> be_equal([
        #(
          "error",
          "\nResults reporter failed\n"
            <> "  The Custom results reporter at position 1 in runner.results_reporters crashed: error:custom_render_crashed\n"
            <> "  Reason: its render function crashed, so this reporter wrote no report.\n"
            <> "  Fix: make the render function return a String for every RunReport.\n"
            <> "\n",
        ),
        #("out", "Custom report: 1 passed, 0 failed\n"),
      ])
      |> or_fail_with("expected the crash error, then the next report")
    }),

    it("names the position of the crashed reporter in the list", fn() {
      run_and_record_streams([passing_suite()], [
        reporter_types.Custom(first_report),
        reporter_types.Custom(coverage_runner_mains.crash_render),
      ])
      |> list.map(stream_and_first_line)
      |> should
      |> be_equal([
        #("out", "first report"),
        #(
          "error",
          "  The Custom results reporter at position 2 in runner.results_reporters crashed: error:custom_render_crashed",
        ),
      ])
      |> or_fail_with(
        "expected the first report, then the error for position 2",
      )
    }),

    it("fails the run report when a reporter crashes", fn() {
      run_without_output([passing_suite()], [
        reporter_types.Custom(coverage_runner_mains.crash_render),
      ])
      |> types.failed
      |> should
      |> be_equal(True)
      |> or_fail_with("a crashed reporter should fail the run")
    }),

    it("keeps the position and the reason of each crash in the report", fn() {
      run_without_output([passing_suite()], [
        reporter_types.Custom(first_report),
        reporter_types.Custom(coverage_runner_mains.crash_render),
        reporter_types.Custom(coverage_runner_mains.crash_render),
      ])
      |> types.report_reporter_crashes
      |> should
      |> be_equal([
        types.ReporterCrash(position: 2, reason: "error:custom_render_crashed"),
        types.ReporterCrash(position: 3, reason: "error:custom_render_crashed"),
      ])
      |> or_fail_with("expected the crashes at positions 2 and 3")
    }),

    it("gives a later reporter the report without the earlier crash", fn() {
      run_and_record_streams([passing_suite()], [
        reporter_types.Custom(coverage_runner_mains.crash_render),
        reporter_types.Custom(crash_count_report),
      ])
      |> list.last
      |> should
      |> be_equal(Ok(#("out", "crashes in the report: 0\n")))
      |> or_fail_with("expected the second reporter to see no crash")
    }),

    it("keeps the full reason of a long crash in the report", fn() {
      run_without_output([passing_suite()], [
        reporter_types.Custom(crash_render_with_long_reason),
      ])
      |> types.report_reporter_crashes
      |> should
      |> be_equal([
        types.ReporterCrash(position: 1, reason: long_crash_reason()),
      ])
      |> or_fail_with("expected the full reason of the crash")
    }),

    it("writes a long crash reason on one line, cut at 200 characters", fn() {
      run_and_record_streams([passing_suite()], [
        reporter_types.Custom(crash_render_with_long_reason),
      ])
      |> should
      |> be_equal([
        #(
          "error",
          "\nResults reporter failed\n"
            <> "  The Custom results reporter at position 1 in runner.results_reporters crashed: "
            <> string.slice(one_line(long_crash_reason()), 0, 200)
            <> " ... (cut at 200 characters, and types.report_reporter_crashes has the full reason)\n"
            <> "  Reason: its render function crashed, so this reporter wrote no report.\n"
            <> "  Fix: make the render function return a String for every RunReport.\n"
            <> "\n",
        ),
      ])
      |> or_fail_with("expected the reason on one line, cut at 200 characters")
    }),

    it("stops a render that does not return and runs the next", fn() {
      run_and_record_streams_with_timeout([passing_suite()], 100, [
        reporter_types.Custom(render_forever),
        reporter_types.Custom(coverage_runner_mains.custom_report),
      ])
      |> should
      |> be_equal([
        #(
          "error",
          "\nResults reporter failed\n"
            <> "  The Custom results reporter at position 1 in runner.results_reporters did not return in 100 ms.\n"
            <> "  Reason: the runner stops a render function that runs longer than runner.default_timeout_ms, so this reporter wrote no report.\n"
            <> "  Fix: make the render function return a String in time, or give runner.default_timeout_ms a larger value.\n"
            <> "\n",
        ),
        #("out", "Custom report: 1 passed, 0 failed\n"),
      ])
      |> or_fail_with("expected the time-out error, then the next report")
    }),

    it("keeps a render that does not return as a crash in the report", fn() {
      runner.new([passing_suite()])
      |> runner.default_timeout_ms(100)
      |> runner.results_reporters([reporter_types.Custom(render_forever)])
      |> runner.output(runner.Output(out: discard, error: discard))
      |> runner.run()
      |> types.report_reporter_crashes
      |> should
      |> be_equal([
        types.ReporterCrash(position: 1, reason: "did not return in 100 ms"),
      ])
      |> or_fail_with("expected the time-out as the crash at position 1")
    }),

    it("writes the crash error of a silent run to the error output", fn() {
      run_main_in_new_vm(
        "dream_test@coverage_runner_mains",
        "silent_run_with_crashing_custom_reporter",
      )
      |> should
      |> be_equal(#(
        0,
        "\nResults reporter failed\n"
          <> "  The Custom results reporter at position 1 in runner.results_reporters crashed: error:custom_render_crashed\n"
          <> "  Reason: its render function crashed, so this reporter wrote no report.\n"
          <> "  Fix: make the render function return a String for every RunReport.\n"
          <> "\n",
      ))
      |> or_fail_with("expected only the crash error and exit status 0")
    })
      |> with_child_timeout,

    it("prints the custom report, then exits 1, for a failed run", fn() {
      run_main_in_new_vm(
        "dream_test@coverage_runner_mains",
        "custom_reporter_failed_run_with_exit_on_failure",
      )
      |> should
      |> be_equal(#(1, "Custom report: 0 passed, 1 failed\n"))
      |> or_fail_with("expected the custom report and exit status 1")
    })
      |> with_child_timeout,
  ])
}

/// The full reason of `crash_render_with_long_reason`, as
/// `sandbox.run_catching` gives it.
fn long_crash_reason() -> String {
  case sandbox.run_catching(crash_render_with_long_reason, empty_report()) {
    Error(reason) -> reason
    Ok(text) -> "the render function did not crash: " <> text
  }
}

fn empty_report() -> types.RunReport {
  types.run_report(tests: [], teardown_failures: [], reporter_crashes: [])
}

/// The lines of `text`, each without the spaces at its start, joined with
/// one space.
fn one_line(text: String) -> String {
  text
  |> string.split("\n")
  |> list.map(string.trim_start)
  |> string.join(" ")
}

/// Run `suites` with `reporters` and an output that keeps nothing, and
/// return the run report.
fn run_without_output(
  suites: List(suite.TestSuite),
  reporters: List(reporter_types.ResultsReporter),
) -> types.RunReport {
  runner.new(suites)
  |> runner.results_reporters(reporters)
  |> runner.output(runner.Output(out: discard, error: discard))
  |> runner.run()
}

fn discard(_text: String) -> Nil {
  Nil
}

/// A render function that never returns.
fn render_forever(_report: types.RunReport) -> String {
  process.sleep_forever()
  "not reached"
}

/// A custom report that gives the number of crashed reporters in the
/// report that it gets.
fn crash_count_report(report: types.RunReport) -> String {
  "crashes in the report: "
  <> int.to_string(list.length(types.report_reporter_crashes(report)))
  <> "\n"
}

fn first_report(_report: types.RunReport) -> String {
  "first report\n"
}

/// The text itself for a custom report, or the reporter that wrote it.
fn report_kind(text: String) -> String {
  case
    string.starts_with(text, "Summary:"),
    string.starts_with(text, "{\"version\":\"2.0\"")
  {
    True, _ -> "bdd"
    False, True -> "json"
    False, False -> text
  }
}

fn passing_suite() {
  describe("passing", [it("passes", fn() { Ok(AssertionOk) })])
}

fn failing_suite() {
  describe("mixed", [
    it("passes", fn() { Ok(AssertionOk) }),
    it("fails", fn() { Error("this test fails") }),
  ])
}

/// Run `suites` with `reporters`, and return every text that the runner
/// wrote to its output, oldest first.
fn run_and_record(
  suites: List(suite.TestSuite),
  reporters: List(reporter_types.ResultsReporter),
) -> List(String) {
  let subject = process.new_subject()
  let _report =
    runner.new(suites)
    |> runner.results_reporters(reporters)
    |> runner.output(
      runner.Output(
        out: fn(text) { process.send(subject, text) },
        error: fn(text) { process.send(subject, text) },
      ),
    )
    |> runner.run()
  received(subject)
}

fn received(subject: Subject(a)) -> List(a) {
  received_loop(subject, [])
}

fn received_loop(subject: Subject(a), acc: List(a)) -> List(a) {
  case process.receive(subject, 0) {
    Ok(text) -> received_loop(subject, [text, ..acc])
    Error(Nil) -> list.reverse(acc)
  }
}

/// Run `suites` with `reporters`, and return every text that the runner
/// wrote, oldest first, each with the stream it went to: "out" or "error".
fn run_and_record_streams(
  suites: List(suite.TestSuite),
  reporters: List(reporter_types.ResultsReporter),
) -> List(#(String, String)) {
  run_and_record_streams_with_timeout(suites, 5000, reporters)
}

/// `run_and_record_streams` with the default timeout `timeout_ms`.
fn run_and_record_streams_with_timeout(
  suites: List(suite.TestSuite),
  timeout_ms: Int,
  reporters: List(reporter_types.ResultsReporter),
) -> List(#(String, String)) {
  let subject = process.new_subject()
  let _report =
    runner.new(suites)
    |> runner.default_timeout_ms(timeout_ms)
    |> runner.results_reporters(reporters)
    |> runner.output(
      runner.Output(out: fn(text) { send_out(subject, text) }, error: fn(text) {
        send_error(subject, text)
      }),
    )
    |> runner.run()
  received(subject)
}

fn send_out(subject: Subject(#(String, String)), text: String) -> Nil {
  process.send(subject, #("out", text))
}

fn send_error(subject: Subject(#(String, String)), text: String) -> Nil {
  process.send(subject, #("error", text))
}

/// The stream and the first line of a text that is not blank.
fn stream_and_first_line(entry: #(String, String)) -> #(String, String) {
  let #(stream, text) = entry
  #(stream, first_line(string.split(text, "\n")))
}

fn first_line(lines: List(String)) -> String {
  case lines {
    [] -> ""
    ["", ..rest] -> first_line(rest)
    ["Results reporter failed", ..rest] -> first_line(rest)
    [line, ..] -> line
  }
}
