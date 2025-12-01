/// Process isolation for test execution.
///
/// This module provides the core mechanism for running tests in isolated
/// BEAM processes with timeout support. Each test runs in its own process,
/// ensuring that crashes in one test do not affect others.
import dream_test/types.{type AssertionResult}
import gleam/erlang/process.{
  type Pid, type Selector, type Subject, kill, monitor, new_selector,
  new_subject, select, select_monitors, selector_receive, send, spawn_unlinked,
}
import gleam/string

/// Configuration for sandboxed test execution.
pub type SandboxConfig {
  SandboxConfig(timeout_ms: Int)
}

/// Result of running a test in an isolated sandbox.
pub type SandboxResult {
  /// Test completed successfully and returned an AssertionResult.
  SandboxCompleted(AssertionResult)
  /// Test did not complete within the timeout period.
  SandboxTimedOut
  /// Test process crashed with the given reason.
  SandboxCrashed(reason: String)
}

/// Internal message type for communication between runner and test worker.
type WorkerMessage {
  TestCompleted(AssertionResult)
  WorkerDown(reason: String)
}

/// Run a test function in an isolated process with timeout.
///
/// The test function runs in a separate BEAM process that is monitored.
/// If the process completes normally, its result is returned.
/// If the process crashes or times out, an appropriate SandboxResult is returned.
pub fn run_isolated(
  config: SandboxConfig,
  test_function: fn() -> AssertionResult,
) -> SandboxResult {
  let result_subject = new_subject()
  let worker_pid = spawn_worker(result_subject, test_function)
  let worker_monitor = monitor(worker_pid)
  let selector = build_result_selector(result_subject)

  wait_for_result(config, selector, worker_pid, worker_monitor)
}

/// Spawn a worker process that runs the test and sends the result.
fn spawn_worker(
  result_subject: Subject(AssertionResult),
  test_function: fn() -> AssertionResult,
) -> Pid {
  spawn_unlinked(fn() {
    let result = test_function()
    send(result_subject, result)
  })
}

/// Build a selector that waits for either test completion or process down.
fn build_result_selector(
  result_subject: Subject(AssertionResult),
) -> Selector(WorkerMessage) {
  new_selector()
  |> select(result_subject)
  |> process.map_selector(map_result_to_message)
  |> select_monitors(map_down_to_message)
}

/// Map a test result to a WorkerMessage.
fn map_result_to_message(result: AssertionResult) -> WorkerMessage {
  TestCompleted(result)
}

/// Map a process down event to a WorkerMessage.
fn map_down_to_message(down: process.Down) -> WorkerMessage {
  let reason = format_exit_reason(down.reason)
  WorkerDown(reason)
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
  selector: Selector(WorkerMessage),
  worker_pid: Pid,
  _worker_monitor: process.Monitor,
) -> SandboxResult {
  case selector_receive(selector, config.timeout_ms) {
    Ok(message) -> handle_worker_message(message)
    Error(Nil) -> handle_timeout(worker_pid)
  }
}

/// Handle a message from the worker or monitor.
fn handle_worker_message(message: WorkerMessage) -> SandboxResult {
  case message {
    TestCompleted(result) -> SandboxCompleted(result)
    WorkerDown(reason) -> SandboxCrashed(reason)
  }
}

/// Handle timeout by killing the worker and returning timeout result.
fn handle_timeout(worker_pid: Pid) -> SandboxResult {
  kill(worker_pid)
  SandboxTimedOut
}

/// Default configuration with a 5 second timeout.
pub fn default_config() -> SandboxConfig {
  SandboxConfig(timeout_ms: 5000)
}
