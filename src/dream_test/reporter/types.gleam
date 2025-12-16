//// Reporter event types for live/progress reporting.
////
//// Most reporters in dream_test are *post-run* formatters (they take the final
//// `List(TestResult)` and render it). These types enable *live* reporting by
//// emitting events as tests complete.
////
//// The runner/parallel modules expose `*_with_events` functions that accept an
//// `on_event` callback. That callback receives values of `ReporterEvent`.
////
//// This module is intentionally small and dependency-light so core execution
//// code can depend on it without importing concrete reporters.

import dream_test/types.{type TestResult}
import gleam/option.{type Option}

/// Lifecycle hook kinds.
pub type HookKind {
  BeforeAll
  BeforeEach
  AfterEach
  AfterAll
}

/// Outcome of a hook run.
pub type HookOutcome {
  HookOk
  HookError(message: String)
}

/// Events emitted during a test run, suitable for progress indicators.
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
  RunFinished(completed: Int, total: Int)
}
