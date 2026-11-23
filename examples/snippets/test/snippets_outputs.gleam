//// The output files that the docs show, under `test/outputs/`. A doc
//// links each output block to one of these files, and a test compares
//// the file with the real output of the code.
////
//// This module is not under `test/snippets/`, so test discovery does not
//// treat it as a suite.

import dream_test/file.{type FileError}
import dream_test/types.{type RunReport, type TestResult, TestResult}
import gleam/list
import gleam/result

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
