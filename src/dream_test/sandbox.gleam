//// Process isolation for test execution (sandboxing).
////
//// This module provides the core mechanism for running a function in an
//// isolated BEAM process with timeout support. It is used internally by the
//// runner and is also useful directly in tests that need strong crash/timeout
//// boundaries.
////
//// ## What problem does this solve?
////
//// Sometimes you want to run code that might:
////
//// - `panic`
//// - hang (never return)
//// - take “too long” and should be timed out
////
//// `run_isolated` runs the function in a separate BEAM process, so the caller
//// stays healthy even if the function crashes.
////
//// ## Selective crash reports
////
//// When a test process crashes (e.g. `panic as "boom"`), Erlang can print a
//// crash report (`=CRASH REPORT==== ...`). This is useful when debugging, but
//// noisy during normal runs.
////
//// `SandboxConfig.show_crash_reports` lets you choose:
////
//// - `False` (default): suppress crash reports and return `SandboxCrashed(...)`
//// - `True`: allow crash reports to print, and still return `SandboxCrashed(...)`
////
//// ## Example
////
//// ```gleam
//// import dream_test/matchers.{be_equal, or_fail_with, should}
//// import dream_test/sandbox.{
////   SandboxCompleted, SandboxConfig, SandboxCrashed, SandboxTimedOut,
//// }
//// import dream_test/unit.{describe, it}
////
//// fn loop_forever() {
////   loop_forever()
//// }
////
//// pub fn tests() {
////   describe("Sandboxing", [
////     it("run_isolated returns SandboxCompleted(value) on success", fn() {
////       let config = SandboxConfig(timeout_ms: 100, show_crash_reports: False)
////       let result = sandbox.run_isolated(config, fn() { 123 })
////
////       result
////       |> should
////       |> be_equal(SandboxCompleted(123))
////       |> or_fail_with("expected SandboxCompleted(123)")
////     }),
////
////     it(
////       "run_isolated returns SandboxTimedOut when the function is too slow",
////       fn() {
////         let config = SandboxConfig(timeout_ms: 10, show_crash_reports: False)
////         let result = sandbox.run_isolated(config, loop_forever)
////
////         result
////         |> should
////         |> be_equal(SandboxTimedOut)
////         |> or_fail_with("expected SandboxTimedOut")
////       },
////     ),
////
////     it("run_isolated returns SandboxCrashed when the function panics", fn() {
////       let config = SandboxConfig(timeout_ms: 100, show_crash_reports: False)
////       let result = sandbox.run_isolated(config, fn() { panic as "boom" })
////
////       let did_crash = case result {
////         SandboxCrashed(_) -> True
////         _ -> False
////       }
////
////       did_crash
////       |> should
////       |> be_equal(True)
////       |> or_fail_with("expected SandboxCrashed(...)")
////     }),
////   ])
//// }
//// ```

import gleam/erlang/process.{
  type Pid, type Selector, type Subject, kill, monitor, new_selector,
  new_subject, select, select_monitors, selector_receive, send, spawn_unlinked,
}
import gleam/string

/// Configuration for sandboxed test execution.
///
/// - `timeout_ms`: how long to wait for the worker to finish before killing it
/// - `show_crash_reports`: whether to allow the BEAM to print crash reports
///
/// ## Example
///
/// ```gleam
/// import dream_test/sandbox.{SandboxConfig}
///
/// let config = SandboxConfig(timeout_ms: 1_000, show_crash_reports: False)
/// ```
///
/// ## Parameters
///
/// - `timeout_ms`: how long to wait before returning `SandboxTimedOut`
/// - `show_crash_reports`: whether to allow the BEAM to print crash reports
///
/// ## Returns
///
/// A `SandboxConfig` value.
pub type SandboxConfig {
  SandboxConfig(timeout_ms: Int, show_crash_reports: Bool)
}

/// Result of running a function in an isolated sandbox.
///
/// This is intentionally simple so it can be used in higher-level code (like a
/// runner) without pulling in reporter concerns.
///
/// ## Variants
///
/// - `SandboxCompleted(value)`: the function completed successfully and returned `value`
/// - `SandboxTimedOut`: the function did not finish within `SandboxConfig.timeout_ms`
/// - `SandboxCrashed(reason)`: the function crashed; `reason` is a best-effort description
pub type SandboxResult(a) {
  /// Function completed successfully and returned a value.
  SandboxCompleted(a)
  /// Test did not complete within the timeout period.
  SandboxTimedOut
  /// Test process crashed with the given reason.
  SandboxCrashed(reason: String)
}

/// Internal message type for communication between runner and test worker.
type WorkerMessage(a) {
  TestCompleted(a)
  WorkerDown(reason: String)
}

@external(erlang, "sandbox_ffi", "run_catching")
fn run_catching(test_function: fn() -> a) -> Result(a, String)

/// Run a test function in an isolated process with timeout.
///
/// The test function runs in a separate BEAM process that is monitored.
/// If the process completes normally, its result is returned.
/// If the process crashes or times out, an appropriate SandboxResult is returned.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/sandbox.{
///   SandboxCompleted, SandboxConfig, SandboxCrashed, SandboxTimedOut,
/// }
/// import dream_test/unit.{describe, it}
///
/// fn loop_forever() {
///   loop_forever()
/// }
///
/// pub fn tests() {
///   describe("Sandboxing", [
///     it("run_isolated returns SandboxCompleted(value) on success", fn() {
///       let config = SandboxConfig(timeout_ms: 100, show_crash_reports: False)
///       let result = sandbox.run_isolated(config, fn() { 123 })
///
///       result
///       |> should
///       |> be_equal(SandboxCompleted(123))
///       |> or_fail_with("expected SandboxCompleted(123)")
///     }),
///
///     it(
///       "run_isolated returns SandboxTimedOut when the function is too slow",
///       fn() {
///         let config = SandboxConfig(timeout_ms: 10, show_crash_reports: False)
///         let result = sandbox.run_isolated(config, loop_forever)
///
///         result
///         |> should
///         |> be_equal(SandboxTimedOut)
///         |> or_fail_with("expected SandboxTimedOut")
///       },
///     ),
///
///     it("run_isolated returns SandboxCrashed when the function panics", fn() {
///       let config = SandboxConfig(timeout_ms: 100, show_crash_reports: False)
///       let result = sandbox.run_isolated(config, fn() { panic as "boom" })
///
///       let did_crash = case result {
///         SandboxCrashed(_) -> True
///         _ -> False
///       }
///
///       did_crash
///       |> should
///       |> be_equal(True)
///       |> or_fail_with("expected SandboxCrashed(...)")
///     }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `config`: sandbox configuration (timeout + crash report behavior)
/// - `test_function`: function to run in an isolated process
///
/// ## Returns
///
/// A `SandboxResult(a)` describing completion, timeout, or crash.
pub fn run_isolated(
  config config: SandboxConfig,
  test_function test_function: fn() -> a,
) -> SandboxResult(a) {
  let result_subject = new_subject()
  let worker_pid =
    spawn_worker(result_subject, test_function, config.show_crash_reports)
  let worker_monitor = monitor(worker_pid)
  let selector =
    build_result_selector(result_subject, config.show_crash_reports)

  wait_for_result(config, selector, worker_pid, worker_monitor)
}

/// Spawn a worker process that runs the test and sends the result.
fn spawn_worker(
  result_subject: Subject(WorkerMessage(a)),
  test_function: fn() -> a,
  show_crash_reports: Bool,
) -> Pid {
  spawn_unlinked(fn() {
    case show_crash_reports {
      True -> {
        let result = test_function()
        send(result_subject, TestCompleted(result))
      }

      False ->
        case run_catching(test_function) {
          Ok(result) -> send(result_subject, TestCompleted(result))
          Error(reason) -> send(result_subject, WorkerDown(reason))
        }
    }
  })
}

/// Build a selector that waits for either test completion or process down.
fn build_result_selector(
  result_subject: Subject(WorkerMessage(a)),
  show_crash_reports: Bool,
) -> Selector(WorkerMessage(a)) {
  case show_crash_reports {
    True ->
      new_selector()
      |> select(result_subject)
      |> select_monitors(map_down_to_message)

    False ->
      // In quiet mode the worker always sends a WorkerMessage, so we don't need
      // to listen to monitor down messages (which would otherwise include Normal).
      new_selector()
      |> select(result_subject)
  }
}

/// Map a process down event to a WorkerMessage.
fn map_down_to_message(down: process.Down) -> WorkerMessage(a) {
  let reason = format_exit_reason(down.reason)
  WorkerDown(reason: reason)
}

/// Format an exit reason as a string for error reporting.
fn format_exit_reason(reason: process.ExitReason) -> String {
  case reason {
    process.Normal -> "normal"
    process.Killed -> "killed"
    process.Abnormal(dynamic_reason) -> string.inspect(dynamic_reason)
  }
}

/// Wait for the worker to complete or timeout.
fn wait_for_result(
  config: SandboxConfig,
  selector: Selector(WorkerMessage(a)),
  worker_pid: Pid,
  _worker_monitor: process.Monitor,
) -> SandboxResult(a) {
  case selector_receive(selector, config.timeout_ms) {
    Ok(message) -> handle_worker_message(message)
    Error(Nil) -> handle_timeout(worker_pid)
  }
}

/// Handle a message from the worker or monitor.
fn handle_worker_message(message: WorkerMessage(a)) -> SandboxResult(a) {
  case message {
    TestCompleted(result) -> SandboxCompleted(result)
    WorkerDown(reason) -> SandboxCrashed(reason)
  }
}

/// Handle timeout by killing the worker and returning timeout result.
fn handle_timeout(worker_pid: Pid) -> SandboxResult(a) {
  kill(worker_pid)
  SandboxTimedOut
}

/// Default configuration with a 5 second timeout.
///
/// Uses `show_crash_reports: False`.
///
/// ## Returns
///
/// A `SandboxConfig` suitable for most tests.
///
/// ## Parameters
///
/// None.
pub fn default_config() -> SandboxConfig {
  SandboxConfig(timeout_ms: 5000, show_crash_reports: False)
}

/// Convenience helper for enabling crash reports in the sandbox.
///
/// This is useful when debugging failures locally.
///
/// ## Example
///
/// ```gleam
/// let config = sandbox.default_config() |> sandbox.with_crash_reports()
/// ```
///
/// ## Parameters
///
/// - `config`: an existing `SandboxConfig`
///
/// ## Returns
///
/// A new `SandboxConfig` with `show_crash_reports: True`.
pub fn with_crash_reports(config config: SandboxConfig) -> SandboxConfig {
  SandboxConfig(..config, show_crash_reports: True)
}
