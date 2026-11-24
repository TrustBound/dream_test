//// How the native line counters behave across runs and processes: a module
//// measured again counts from zero, two runs in one BEAM count apart, and
//// code that runs before coverage starts is left alone.

import dream_test/coverage
import dream_test/coverage/report.{type CoverageReport, LineCoverage}
import dream_test/coverage_project_support.{
  add_source, ask, call_answer, compile_source, is_alive, measure, project,
  project_config, start_server,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}

/// Create a project with one module whose `answer/0` is on line 3, and
/// return its source directory.
fn answer_project(name: String, module: String) -> String {
  let source_directory = project(name)
  add_source(
    source_directory,
    module <> ".erl",
    "-module(" <> module <> ").\n-export([answer/0]).\nanswer() -> 42.\n",
  )
  compile_source(source_directory, module <> ".erl", "debug_info")
  source_directory
}

/// Create a project with one module whose `serve/0` (line 3) answers with
/// `answer/0` (line 4), and return its source directory.
fn server_project(name: String, module: String) -> String {
  let source_directory = project(name)
  add_source(
    source_directory,
    module <> ".erl",
    "-module("
      <> module
      <> ").\n-export([serve/0, answer/0]).\nserve() -> receive {ask, From} -> From ! {answer, answer()}, serve() end.\nanswer() -> 42.\n",
  )
  compile_source(source_directory, module <> ".erl", "debug_info")
  source_directory
}

fn report_of(
  result: Result(CoverageReport, coverage.CoverageError),
) -> Result(CoverageReport, String) {
  case result {
    Ok(coverage_report) -> Ok(coverage_report)
    Error(_) -> Error("expected the run to finish")
  }
}

pub fn tests() {
  describe("native line counters", [
    it("count from zero when a module is measured again", fn() {
      let source_directory = answer_project("again", "native_again")
      let config = project_config(source_directory)
      let _ =
        measure(config, fn() {
          call_answer("native_again")
          call_answer("native_again")
        })
      measure(config, fn() { call_answer("native_again") })
      |> report_of()
      |> should
      |> be_equal(
        Ok(
          report.new([
            report.file(
              "test/../build/coverage/projects/again/src/native_again.erl",
              [LineCoverage(line: 3, calls: 1)],
            ),
          ]),
        ),
      )
      |> or_fail_with("expected one call in the second run")
    }),
    it("count two runs at the same time apart", fn() {
      let first = answer_project("first_run", "native_first")
      let second = answer_project("second_run", "native_second")
      let assert Ok(first_session) = coverage.start(project_config(first))
      let assert Ok(second_session) = coverage.start(project_config(second))
      call_answer("native_first")
      call_answer("native_second")
      call_answer("native_second")
      let _ = coverage.finish(first_session)
      coverage.finish(second_session)
      |> report_of()
      |> should
      |> be_equal(
        Ok(
          report.new([
            report.file(
              "test/../build/coverage/projects/second_run/src/native_second.erl",
              [LineCoverage(line: 3, calls: 2)],
            ),
          ]),
        ),
      )
      |> or_fail_with("expected only the second run's two calls")
    }),
    it("do not count code that a process ran before the start", fn() {
      let source_directory = server_project("running", "native_running")
      let server = start_server("native_running")
      measure(project_config(source_directory), fn() {
        ask(server)
        call_answer("native_running")
      })
      |> report_of()
      |> should
      |> be_equal(
        Ok(
          report.new([
            report.file(
              "test/../build/coverage/projects/running/src/native_running.erl",
              [LineCoverage(line: 3, calls: 0), LineCoverage(line: 4, calls: 1)],
            ),
          ]),
        ),
      )
      |> or_fail_with("expected only the direct call to answer/0")
    }),
    it("keep a process that runs old code alive", fn() {
      let source_directory = server_project("still_running", "native_alive")
      let server = start_server("native_alive")
      let _ = measure(project_config(source_directory), fn() { ask(server) })
      is_alive(server)
      |> should
      |> be_equal(True)
      |> or_fail_with("expected the process to keep running")
    }),
  ])
}
