//// Configuration types of the results reporters.
////
//// `runner.results_reporters(...)` takes a list of `ResultsReporter`
//// values. Each one formats the run report once, at the end of the run.
//// The live progress bar has its own event type,
//// `dream_test/reporters/progress.ProgressEvent`.

import dream_test/types.{type RunReport}

// ============================================================================
// Results reporter configuration (end-of-run)
// ============================================================================

/// Which parts of a BDD report to print at the end of the run.
pub type BddOutputMode {
  /// Print the full hierarchical results, then repeat failures, then summary.
  BddFull
  /// Print failures (repeated), the set-up and tear-down failures, and the
  /// summary.
  BddFailuresOnly
  /// Print the summary, after the set-up and tear-down failures when there
  /// are any.
  BddSummaryOnly
}

/// Configuration for the BDD results reporter.
pub type BddReporterConfig {
  BddReporterConfig(color: Bool, mode: BddOutputMode)
}

/// Configuration for the JSON results reporter.
pub type JsonReporterConfig {
  JsonReporterConfig(pretty: Bool)
}

/// Results reporters format the end-of-run results into one output block each.
///
/// They are executed in the order provided to `runner.results_reporters(...)`.
/// The runner writes every report before it checks coverage, and before
/// `runner.exit_on_failure()` ends the program. Thus each report prints,
/// also when the run fails.
pub type ResultsReporter {
  /// The BDD report. Make it with `dream_test/reporters/bdd.new()`.
  Bdd(BddReporterConfig)
  /// The JSON report. Make it with `dream_test/reporters/json.new()`.
  Json(JsonReporterConfig)
  /// Your own report format. At the end of the run, the runner calls
  /// `render` one time with the run report, and writes the text that it
  /// returns. The runner adds no newline, so end the text with `"\n"`.
  ///
  /// ```gleam
  /// import dream_test/reporters/types as reporter_types
  /// import dream_test/runner
  /// import dream_test/types.{type RunReport}
  ///
  /// fn my_report(report: RunReport) -> String {
  ///   case types.failed(report) {
  ///     True -> "My report: failed\n"
  ///     False -> "My report: passed\n"
  ///   }
  /// }
  ///
  /// pub fn main() {
  ///   runner.new([tests()])
  ///   |> runner.results_reporters([reporter_types.Custom(my_report)])
  ///   |> runner.exit_on_failure()
  ///   |> runner.run()
  /// }
  /// ```
  Custom(render: fn(RunReport) -> String)
}
