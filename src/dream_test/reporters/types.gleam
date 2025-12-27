//// Reporter event types emitted during a run.
////
//// These types are produced by Dream Test’s runner/executors and consumed by
//// reporters (see `dream_test/reporters`). You usually don’t construct events
//// yourself; you pattern match on them if you’re implementing a custom
//// reporter.
////
//// ## Terminology
////
//// - **scope**: the describe/group path for where something happened
////   (example: `["file", "delete"]`)
//// - **test_name**: the leaf `it(...)` name for per-test hooks
//// - **completed / total**: counts for progress UIs; `completed` is 1-based and
////   increases monotonically
////
//// ## Event model
////
//// A typical run looks like:
////
//// - `RunStarted(total)`
//// - many `TestFinished(completed, total, result)` (in completion order)
//// - `RunFinished(completed, total, results)`
////
//// Hook events (`HookStarted` / `HookFinished`) can be interleaved when you use
//// lifecycle hooks.

import dream_test/types.{type TestResult}
import gleam/option.{type Option}

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

/// Which lifecycle hook is running.
///
/// ## Example
///
/// ```gleam
/// let event =
///   reporter_types.HookFinished(
///     kind: reporter_types.AfterEach,
///     scope: ["file"],
///     test_name: Some("delete"),
///     outcome: reporter_types.HookError(message: "boom"),
///   )
/// ```
pub type HookKind {
  BeforeAll
  BeforeEach
  AfterEach
  AfterAll
}

/// Whether a hook succeeded or failed.
///
/// ## Example
///
/// ```gleam
/// use message <- result.try(hook_error_message(event))
///
/// message
/// |> should
/// |> be_equal("boom")
/// |> or_fail_with("expected hook error message 'boom'")
/// ```
pub type HookOutcome {
  HookOk
  HookError(message: String)
}

/// Events emitted during a test run, suitable for progress indicators.
///
/// `scope` is the describe/group path (e.g. `["file", "delete"]`).
/// For per-test hooks, `test_name` is the leaf `it` name.
///
/// ## Example
///
/// ```gleam
/// use total <- result.try(
///   run_started_total(reporter_types.RunStarted(total: 3)),
/// )
///
/// total
/// |> should
/// |> be_equal(3)
/// |> or_fail_with("expected total to be 3")
/// ```
pub type ReporterEvent {
  /// The run is starting, and this many tests will be attempted.
  RunStarted(total: Int)
  /// One test finished (pass/fail/skip/timeout/setup failure).
  ///
  /// `completed` is 1-based and increases monotonically until it reaches `total`.
  TestFinished(completed: Int, total: Int, result: TestResult)
  /// A hook is about to run.
  HookStarted(kind: HookKind, scope: List(String), test_name: Option(String))
  /// A hook finished running.
  HookFinished(
    kind: HookKind,
    scope: List(String),
    test_name: Option(String),
    outcome: HookOutcome,
  )
  /// The run finished. `completed` should equal `total`.
  ///
  /// `results` are in traversal order (deterministic), regardless of parallel execution.
  RunFinished(completed: Int, total: Int, results: List(TestResult))
}
