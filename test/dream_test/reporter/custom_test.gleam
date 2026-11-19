//// Black-box tests of the custom results reporter,
//// `reporter_types.Custom(render)`.

import dream_test/child_timeout.{with_child_timeout}
import dream_test/coverage_runner_mains
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/json
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/suite
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/string

@external(erlang, "dream_test_coverage_test_ffi", "run_main_in_new_vm")
fn run_main_in_new_vm(module: String, function: String) -> #(Int, String)

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

fn received(subject: Subject(String)) -> List(String) {
  received_loop(subject, [])
}

fn received_loop(subject: Subject(String), acc: List(String)) -> List(String) {
  case process.receive(subject, 0) {
    Ok(text) -> received_loop(subject, [text, ..acc])
    Error(Nil) -> list.reverse(acc)
  }
}
