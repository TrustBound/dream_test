//// Reporter event types for live/progress reporting.
////
//// These types are emitted by the runner/parallel execution code and consumed
//// by event-driven reporters (see `dream_test/reporters`).
////
//// Most users should not need to construct these values directly; you’ll
//// typically choose a reporter with `dream_test/reporters` and attach it to
//// `runner` so events are handled automatically.
////
//// ## Terminology
////
//// - **scope**: the describe/group path for where something happened.
////   Example: `["File", "delete"]`
//// - **test_name**: the leaf `it(...)` name for per-test hooks (BeforeEach/AfterEach).
//// - **completed / total**: monotonically increasing counts used by progress UIs.
////
//// ## Event model (high level)
////
//// A run looks like:
////
//// - `RunStarted(total)`
//// - many `TestFinished(completed, total, result)` (in completion order)
//// - `RunFinished(completed, total)`
////
//// Hook events may be interleaved for suites that declare hooks.

import dream_test/types.{type TestResult}
import gleam/option.{type Option}

/// Lifecycle hook kinds.
///
/// Hook events include a `kind` plus contextual information (`scope` and an
/// optional `test_name` for per-test hooks).
pub type HookKind {
  BeforeAll
  BeforeEach
  AfterEach
  AfterAll
}

/// Outcome of a hook run.
///
/// Hook failures are represented as `HookError(String)`.
pub type HookOutcome {
  HookOk
  HookError(message: String)
}

/// Events emitted during a test run, suitable for progress indicators.
///
/// `scope` is the describe/group path (e.g. `["file", "delete"]`).
/// For per-test hooks, `test_name` is the leaf `it` name.
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
