//// Configuration types of the results reporters.
////
//// `runner.results_reporters(...)` takes a list of `ResultsReporter`
//// values. Each one formats the run report once, at the end of the run.
//// The live progress bar has its own event type,
//// `dream_test/reporters/progress.ProgressEvent`.

// ============================================================================
// Results reporter configuration (end-of-run)
// ============================================================================

/// Which parts of a BDD report to print at the end of the run.
pub type BddOutputMode {
  /// Print the full hierarchical results, then repeat failures, then summary.
  BddFull
  /// Print failures (repeated) and summary only.
  BddFailuresOnly
  /// Print summary only.
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
pub type ResultsReporter {
  Bdd(BddReporterConfig)
  Json(JsonReporterConfig)
}
