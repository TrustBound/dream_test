//// The output files that the docs show, under `test/outputs/`. A doc
//// links each output block to one of these files, and a test compares
//// the file with the real output of the code.
////
//// This module is not under `test/snippets/`, so test discovery does not
//// treat it as a suite.

import dream_test/file.{type FileError}
import dream_test/reporters/bdd
import dream_test/reporters/json
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport, type TestResult, TestResult}
import gleam/list
import gleam/result
import snippets_child_vm

/// The folder of the output files, from the snippets project.
const outputs_folder = "test/outputs/"

/// Reads `test/outputs/<name>.txt`.
pub fn read(name: String) -> Result(String, FileError) {
  file.read(outputs_folder <> name <> ".txt")
}

/// Reads `test/outputs/<name>.txt`, with a blank line before it. The
/// coverage table starts with a blank line, which the output files leave
/// out.
pub fn read_after_blank_line(name: String) -> Result(String, FileError) {
  read(name)
  |> result.map(after_blank_line)
}

fn after_blank_line(text: String) -> String {
  "\n" <> text
}

/// The report with the duration of every test set to 0, so that a
/// reporter gives the same text in every run.
pub fn without_durations(report: RunReport) -> RunReport {
  types.run_report(
    tests: list.map(types.report_tests(report), without_duration),
    hook_failures: types.report_hook_failures(report),
    reporter_crashes: types.report_reporter_crashes(report),
  )
}

fn without_duration(result: TestResult) -> TestResult {
  TestResult(..result, duration_ms: 0)
}

/// Reads `test/outputs/<name>.txt`, with a file error as text.
pub fn expected(name: String) -> Result(String, String) {
  read(name)
  |> result.map_error(file.error_to_string)
}

/// Runs `suites` with no output, and gives the report as `bdd.new()`
/// prints it at the end of a run: with no colour and every test, and with
/// every duration set to 0, so the text is the same in every run.
pub fn bdd_report(suites: List(TestSuite)) -> String {
  runner.new(suites)
  |> runner.silent()
  |> runner.run()
  |> render_with_bdd(reporter_types.BddFull)
}

/// The report as the bdd reporter prints it in `mode`, with no colour, and
/// with every duration set to 0.
pub fn render_with_bdd(
  report: RunReport,
  mode: reporter_types.BddOutputMode,
) -> String {
  bdd.render(
    config: reporter_types.BddReporterConfig(color: False, mode: mode),
    report: without_durations(report),
  )
}

/// Runs `function` of the Gleam module `module` in a child VM, and gives
/// its exit status and its standard output. The output is made the same in
/// every run: only the last state of the progress line stays, the
/// durations after the test names are removed, and the duration of the run
/// in the summary line is `0ms`, as in a report whose durations are 0.
pub fn child_output(
  module: String,
  function: String,
) -> Result(#(Int, String), String) {
  snippets_child_vm.run(module, function)
  |> result.map(status_and_stable_output)
}

fn status_and_stable_output(run: snippets_child_vm.ChildRun) -> #(Int, String) {
  #(run.status, stable_output(run.output))
}

fn stable_output(output: String) -> String {
  snippets_child_vm.without_progress_and_durations(output)
  |> snippets_child_vm.replace(" in <duration>", " in 0ms")
}

/// The exit status and the output file `test/outputs/<name>.txt` that a
/// child VM run must give.
pub fn expected_run(
  status: Int,
  name: String,
) -> Result(#(Int, String), String) {
  expected(name)
  |> result.map(with_status(status, _))
}

fn with_status(status: Int, output: String) -> #(Int, String) {
  #(status, output)
}

/// The JSON report of a run, pretty, with every duration set to 0, the
/// time of the report set to 0, and the OTP release as `<release>`, so the
/// text is the same on every machine.
pub fn stable_json(report: RunReport) -> String {
  json.format_pretty(without_durations(report))
  |> snippets_child_vm.replace(
    "\"timestamp_ms\": [0-9]+",
    "\"timestamp_ms\": 0",
  )
  |> snippets_child_vm.replace(
    "\"otp_version\": \"[0-9]+\"",
    "\"otp_version\": \"<release>\"",
  )
}

/// `child_output` for a function that measures coverage: it runs while no
/// other snippet test measures coverage. Gives the exit status, the stable
/// output and the error output.
pub fn child_output_with_coverage(
  module: String,
  function: String,
) -> Result(#(Int, String, String), String) {
  snippets_child_vm.run_with_coverage_lock(module, function, [])
  |> result.map(status_and_both_outputs)
}

fn status_and_both_outputs(
  run: snippets_child_vm.ChildRun,
) -> #(Int, String, String) {
  #(run.status, stable_output(run.output), run.error_output)
}
