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
  type Monitor, type Pid, type Selector, type Subject, demonitor_process, kill,
  monitor, new_selector, new_subject, select, select_specific_monitor,
  selector_receive, send, spawn_unlinked,
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
  let selector = build_result_selector(result_subject, worker_monitor)

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
///
/// Only the down message of this worker's monitor is selected, so down
/// messages of other monitors of the calling process stay in its mailbox.
/// The worker sends its result before it exits, so the result comes before
/// the down message of a normal exit. The down message is needed in both
/// modes: an exit signal (for example from a linked process that crashed)
/// stops the worker before it can send anything.
fn build_result_selector(
  result_subject: Subject(WorkerMessage(a)),
  worker_monitor: Monitor,
) -> Selector(WorkerMessage(a)) {
  new_selector()
  |> select(result_subject)
  |> select_specific_monitor(worker_monitor, map_down_to_message)
}

/// Map a process down event to a WorkerMessage.
fn map_down_to_message(down: process.Down) -> WorkerMessage(a) {
  let reason = format_exit_reason(down.reason)
  WorkerDown(reason: reason)
}

/// Format an exit reason as a string for error reporting. The parallel
/// executor uses it too, for a test worker that exits before it sends its
/// result.
@internal
pub fn format_exit_reason(reason: process.ExitReason) -> String {
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
  worker_monitor: Monitor,
) -> SandboxResult(a) {
  let result = case selector_receive(selector, config.timeout_ms) {
    Ok(message) -> handle_worker_message(message)
    Error(Nil) -> handle_timeout(worker_pid)
  }
  // Remove the monitor and any down message it left in the mailbox, so the
  // caller's mailbox does not fill up and a later selector cannot see it.
  demonitor_process(worker_monitor)
  result
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
