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
//// `run_in_owner` runs functions one after another in an owner process that
//// stays alive between them, so a resource that one function starts lives
//// for the next one. The runner uses one owner for the hooks of each scope.
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
//// fn double(number: Int) -> Int {
////   number * 2
//// }
////
//// fn loop_forever(_input: Nil) -> Nil {
////   loop_forever(Nil)
//// }
////
//// fn crash(message: String) -> Int {
////   panic as message
//// }
////
//// pub fn tests() {
////   describe("Sandboxing", [
////     it("run_isolated returns SandboxCompleted(value) on success", fn() {
////       let config = SandboxConfig(timeout_ms: 100, show_crash_reports: False)
////       let result = sandbox.run_isolated(config, double, 61)
////
////       result
////       |> should
////       |> be_equal(SandboxCompleted(122))
////       |> or_fail_with("expected SandboxCompleted(122)")
////     }),
////
////     it(
////       "run_isolated returns SandboxTimedOut when the function is too slow",
////       fn() {
////         let config = SandboxConfig(timeout_ms: 10, show_crash_reports: False)
////         let result = sandbox.run_isolated(config, loop_forever, Nil)
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
////       let result = sandbox.run_isolated(config, crash, "boom")
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
  monitor, new_selector, new_subject, receive_forever, select, select_map,
  select_specific_monitor, selector_receive, selector_receive_forever, send,
  spawn_unlinked,
}
import gleam/option.{type Option, None, Some}
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

/// Run a function with its input in the calling process, and turn a crash
/// into an `Error`.
///
/// Use this function for code that must run in the calling process, for
/// example a hook that starts a resource which must live as long as the
/// caller. A process that the function links to, and an ETS table that it
/// makes, stay alive after the function returns.
///
/// No new process starts, so no timeout applies: a function that never
/// returns blocks the caller. A crash (`panic`, `erlang:error`, `throw` or
/// `exit` in the calling process) becomes `Error` with the class and the
/// reason. An exit signal that another process sends is not caught.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/sandbox
/// import dream_test/unit.{describe, it}
///
/// fn double(number: Int) -> Int {
///   number * 2
/// }
///
/// pub fn tests() {
///   describe("run_catching", [
///     it("returns the value of a function that returns", fn() {
///       sandbox.run_catching(double, 61)
///       |> should
///       |> be_equal(Ok(122))
///       |> or_fail_with("expected Ok(122)")
///     }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `run`: the function to run in the calling process
/// - `input`: the argument that `run` gets
///
/// ## Returns
///
/// `Ok(value)` when `run` returns, or `Error("class:reason")` when it
/// crashes, for example `Error("error:boom")`.
@external(erlang, "sandbox_ffi", "run_catching")
pub fn run_catching(
  run run: fn(input) -> a,
  input input: input,
) -> Result(a, String)

/// Run a function with its input in an isolated process with timeout.
///
/// The function runs in a separate BEAM process that is monitored, and gets
/// `input` as its argument. Give the data that the function needs as
/// `input`, so the function can be a named function.
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
/// fn double(number: Int) -> Int {
///   number * 2
/// }
///
/// fn loop_forever(_input: Nil) -> Nil {
///   loop_forever(Nil)
/// }
///
/// fn crash(message: String) -> Int {
///   panic as message
/// }
///
/// pub fn tests() {
///   describe("Sandboxing", [
///     it("run_isolated returns SandboxCompleted(value) on success", fn() {
///       let config = SandboxConfig(timeout_ms: 100, show_crash_reports: False)
///       let result = sandbox.run_isolated(config, double, 61)
///
///       result
///       |> should
///       |> be_equal(SandboxCompleted(122))
///       |> or_fail_with("expected SandboxCompleted(122)")
///     }),
///
///     it(
///       "run_isolated returns SandboxTimedOut when the function is too slow",
///       fn() {
///         let config = SandboxConfig(timeout_ms: 10, show_crash_reports: False)
///         let result = sandbox.run_isolated(config, loop_forever, Nil)
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
///       let result = sandbox.run_isolated(config, crash, "boom")
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
/// - `run`: function to run in an isolated process
/// - `input`: the argument that `run` gets
///
/// ## Returns
///
/// A `SandboxResult(a)` describing completion, timeout, or crash.
pub fn run_isolated(
  config config: SandboxConfig,
  run run: fn(input) -> a,
  input input: input,
) -> SandboxResult(a) {
  let result_subject = new_subject()
  let worker_pid =
    spawn_worker(result_subject, run, input, config.show_crash_reports)
  let worker_monitor = monitor(worker_pid)
  let selector = build_result_selector(result_subject, worker_monitor)

  wait_for_result(config, selector, worker_pid, worker_monitor)
}

/// Spawn a worker process that runs the function and sends the result.
fn spawn_worker(
  result_subject: Subject(WorkerMessage(a)),
  run: fn(input) -> a,
  input: input,
  show_crash_reports: Bool,
) -> Pid {
  spawn_unlinked(fn() {
    run_worker(result_subject, run, input, show_crash_reports)
  })
}

/// The body of the worker process: run the function and send its result.
/// With crash reports off, a crash is caught and sent as `WorkerDown`.
fn run_worker(
  result_subject: Subject(WorkerMessage(a)),
  run: fn(input) -> a,
  input: input,
  show_crash_reports: Bool,
) -> Nil {
  case show_crash_reports {
    True -> send(result_subject, TestCompleted(run(input)))
    False -> send(result_subject, caught_message(run_catching(run, input)))
  }
}

/// The worker message for the result of a caught run.
fn caught_message(result: Result(a, String)) -> WorkerMessage(a) {
  case result {
    Ok(value) -> TestCompleted(value)
    Error(reason) -> WorkerDown(reason)
  }
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

/// Render a process exit reason as text, the same way dream_test does.
///
/// `run_isolated` puts this text in `SandboxCrashed` when a worker exits
/// before it sends a result, and the parallel executor puts it in the
/// failure message of a test whose worker stops. Use it in a custom runner,
/// or with your own process monitors, to show a crash reason in the same
/// form as dream_test.
///
/// - `Normal` gives `"normal"`.
/// - `Killed` gives `"killed"`.
/// - `Abnormal(reason)` gives `string.inspect(reason)`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/sandbox
/// import dream_test/unit.{describe, it}
/// import gleam/dynamic
/// import gleam/erlang/process
///
/// pub fn tests() {
///   describe("Exit reasons", [
///     it("format_exit_reason shows an abnormal reason as Gleam text", fn() {
///       process.Abnormal(dynamic.string("boom"))
///       |> sandbox.format_exit_reason
///       |> should
///       |> be_equal("\"boom\"")
///       |> or_fail_with("expected the quoted reason")
///     }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `reason`: the exit reason from a `process.Down` message or an exit
///   signal
///
/// ## Returns
///
/// The exit reason as text.
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

// =============================================================================
// Owner processes
// =============================================================================

/// A process that runs functions one after another and stays alive between
/// them, so that what a function starts lives until the owner stops.
///
/// An owner is the process of one scope: for example, the `before_all`
/// hook of a group starts a pool in the owner, the tests of the group use
/// the pool, and the `after_all` hook stops the pool in the same owner. A
/// process that a function links to, and an ETS table that it makes, live
/// as long as the owner.
///
/// Get an owner from `run_in_owner`, and stop it with `stop_owner`. The
/// value is opaque, so only an owner that answered can be used again.
pub opaque type Owner(input, output) {
  Owner(
    pid: Pid,
    monitor: Monitor,
    requests: Subject(OwnerRequest(input, output)),
  )
}

/// The result of `run_in_owner`.
///
/// ## Variants
///
/// - `OwnerReturned(owner, value)`: the function returned `value`. The
///   owner is alive and can run the next function.
/// - `OwnerCaught(owner, reason)`: the function crashed (`panic`,
///   `erlang:error`, `throw` or `exit` in the owner) and the owner caught
///   the crash. `reason` is `"class:reason"`, as from `run_catching`. The
///   owner is alive and can run the next function.
/// - `OwnerTimedOut`: the function did not return in time. The owner was
///   killed, so a process that links to it stops too.
/// - `OwnerExited(reason)`: the owner stopped before the function
///   returned, for example because a process that links to it crashed.
///   `reason` is the exit reason as text, from `format_exit_reason`.
pub type OwnerResult(input, output) {
  OwnerReturned(owner: Owner(input, output), value: output)
  OwnerCaught(owner: Owner(input, output), reason: String)
  OwnerTimedOut
  OwnerExited(reason: String)
}

/// A message to an owner: run a function, or stop.
type OwnerRequest(input, output) {
  RunRequest(
    run: fn(input) -> output,
    input: input,
    reply: Subject(OwnerReply(input, output)),
  )
  StopRequest
}

/// The answer of an owner to a `RunRequest`. It names the subject of the
/// owner, so the first answer tells the caller where to send later
/// requests.
type OwnerReply(input, output) {
  OwnerReply(
    requests: Subject(OwnerRequest(input, output)),
    result: Result(output, String),
  )
}

/// What the caller gets while it waits for an owner.
type OwnerEvent(input, output) {
  OwnerAnswered(reply: OwnerReply(input, output))
  OwnerWentDown(reason: String)
}

/// Run a function with its input in an owner process, and wait for it with
/// a timeout.
///
/// With `None`, a new owner starts and runs the function. With
/// `Some(owner)`, that owner runs the function, so the function sees what
/// earlier functions started there. The caller monitors the owner, so a
/// crash of the owner never stops the caller.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/sandbox.{OwnerReturned}
/// import dream_test/unit.{describe, it}
/// import gleam/option.{None}
///
/// fn double(number: Int) -> Int {
///   number * 2
/// }
///
/// fn value(result: sandbox.OwnerResult(Int, Int)) -> Result(Int, Nil) {
///   case result {
///     OwnerReturned(owner: owner, value: value) -> {
///       sandbox.stop_owner(owner)
///       Ok(value)
///     }
///     _ -> Error(Nil)
///   }
/// }
///
/// pub fn tests() {
///   describe("Owner processes", [
///     it("run_in_owner returns the value of the function", fn() {
///       sandbox.run_in_owner(None, 100, double, 21)
///       |> value
///       |> should
///       |> be_equal(Ok(42))
///       |> or_fail_with("expected Ok(42)")
///     }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `owner`: the owner that runs the function, or `None` for a new owner
/// - `timeout_ms`: how long to wait before the owner is killed
/// - `run`: the function to run in the owner
/// - `input`: the argument that `run` gets
///
/// ## Returns
///
/// An `OwnerResult`: the value or caught crash with the owner that is still
/// alive, or the timeout or exit of the owner.
pub fn run_in_owner(
  owner owner: Option(Owner(input, output)),
  timeout_ms timeout_ms: Int,
  run run: fn(input) -> output,
  input input: input,
) -> OwnerResult(input, output) {
  let reply = new_subject()
  let request = RunRequest(run: run, input: input, reply: reply)
  let #(pid, owner_monitor) = send_owner_request(owner, request)
  let selector =
    new_selector()
    |> select_map(reply, OwnerAnswered)
    |> select_specific_monitor(owner_monitor, owner_went_down)
  case selector_receive(selector, timeout_ms) {
    Ok(OwnerAnswered(OwnerReply(requests: requests, result: Ok(value)))) ->
      OwnerReturned(
        owner: Owner(pid: pid, monitor: owner_monitor, requests: requests),
        value: value,
      )
    Ok(OwnerAnswered(OwnerReply(requests: requests, result: Error(reason)))) ->
      OwnerCaught(
        owner: Owner(pid: pid, monitor: owner_monitor, requests: requests),
        reason: reason,
      )
    Ok(OwnerWentDown(reason: reason)) -> OwnerExited(reason: reason)
    Error(Nil) -> {
      kill(pid)
      demonitor_process(owner_monitor)
      OwnerTimedOut
    }
  }
}

/// Give the request to the owner, or start a new owner with it. Gives the
/// process and the monitor of the owner.
fn send_owner_request(
  owner: Option(Owner(input, output)),
  request: OwnerRequest(input, output),
) -> #(Pid, Monitor) {
  case owner {
    Some(Owner(pid: pid, monitor: owner_monitor, requests: requests)) -> {
      send(requests, request)
      #(pid, owner_monitor)
    }
    None -> {
      let pid = spawn_unlinked(fn() { start_owner(request) })
      #(pid, monitor(pid))
    }
  }
}

fn owner_went_down(down: process.Down) -> OwnerEvent(input, output) {
  OwnerWentDown(reason: format_exit_reason(down.reason))
}

/// The body of an owner process: make the subject for later requests, then
/// serve the first request.
fn start_owner(first: OwnerRequest(input, output)) -> Nil {
  serve_owner(new_subject(), first)
}

/// Run each request in the owner process until a `StopRequest`. A crash of
/// a function is caught, so the owner stays alive.
fn serve_owner(
  requests: Subject(OwnerRequest(input, output)),
  request: OwnerRequest(input, output),
) -> Nil {
  case request {
    RunRequest(run: run, input: input, reply: reply) -> {
      send(
        reply,
        OwnerReply(requests: requests, result: run_catching(run, input)),
      )
      serve_owner(requests, receive_forever(requests))
    }
    StopRequest -> Nil
  }
}

/// Check that an owner is still alive before the caller gives it more
/// work.
///
/// An owner can stop between two functions, for example when a process
/// that links to it crashes while the tests of its scope run. Use this
/// function before the tear-down of a scope, to report that exit and to
/// run the tear-down in a new owner.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/sandbox.{OwnerReturned}
/// import dream_test/unit.{describe, it}
/// import gleam/option.{None}
///
/// fn double(number: Int) -> Int {
///   number * 2
/// }
///
/// fn still_alive(result: sandbox.OwnerResult(Int, Int)) -> Bool {
///   case result {
///     OwnerReturned(owner: owner, value: _) -> {
///       let alive = case sandbox.check_owner(owner) {
///         Ok(_owner) -> True
///         Error(_reason) -> False
///       }
///       sandbox.stop_owner(owner)
///       alive
///     }
///     _ -> False
///   }
/// }
///
/// pub fn tests() {
///   describe("Owner processes", [
///     it("check_owner gives back an owner that is alive", fn() {
///       sandbox.run_in_owner(None, 100, double, 21)
///       |> still_alive
///       |> should
///       |> be_equal(True)
///       |> or_fail_with("expected the owner to be alive")
///     }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `owner`: an owner from `run_in_owner`
///
/// ## Returns
///
/// `Ok(owner)` when the owner is alive, or `Error(reason)` with the exit
/// reason as text when it stopped. After `Error`, do not use the owner
/// again.
pub fn check_owner(
  owner owner: Owner(input, output),
) -> Result(Owner(input, output), String) {
  let selector =
    new_selector()
    |> select_specific_monitor(owner.monitor, owner_down_reason)
  case selector_receive(selector, 0) {
    Ok(reason) -> Error(reason)
    Error(Nil) -> Ok(owner)
  }
}

fn owner_down_reason(down: process.Down) -> String {
  format_exit_reason(down.reason)
}

/// Stop an owner and wait until it has exited.
///
/// The owner exits with reason `normal`. An ETS table that it made is
/// deleted, and a process that links to it and traps exits, such as a
/// supervisor, gets the exit signal and stops. When `stop_owner` returns,
/// the owner has exited, so a later scope can make a table with the same
/// name. An owner that stopped already is not an error.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/sandbox.{OwnerReturned}
/// import dream_test/unit.{describe, it}
/// import gleam/option.{None}
///
/// fn double(number: Int) -> Int {
///   number * 2
/// }
///
/// fn stop(result: sandbox.OwnerResult(Int, Int)) -> Bool {
///   case result {
///     OwnerReturned(owner: owner, value: _) -> {
///       sandbox.stop_owner(owner)
///       True
///     }
///     _ -> False
///   }
/// }
///
/// pub fn tests() {
///   describe("Owner processes", [
///     it("stop_owner stops an owner", fn() {
///       sandbox.run_in_owner(None, 100, double, 21)
///       |> stop
///       |> should
///       |> be_equal(True)
///       |> or_fail_with("expected the owner to stop")
///     }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `owner`: an owner from `run_in_owner`
///
/// ## Returns
///
/// `Nil`, after the owner has exited.
pub fn stop_owner(owner owner: Owner(input, output)) -> Nil {
  send(owner.requests, StopRequest)
  let selector =
    new_selector()
    |> select_specific_monitor(owner.monitor, owner_down_reason)
  let _reason = selector_receive_forever(selector)
  Nil
}
