import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox
import dream_test/types.{
  type AssertionResult, AssertionFailed, AssertionFailure, AssertionOk,
}
import dream_test/unit.{describe, it}
import gleam/dynamic
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process
import gleam/option.{None}
import gleam/string

pub fn tests() {
  describe("dream_test/sandbox", [
    it("returns SandboxCompleted on success", fn() {
      let config =
        sandbox.SandboxConfig(timeout_ms: 100, show_crash_reports: False)
      case sandbox.run_isolated(config, fn(_input) { AssertionOk }, Nil) {
        sandbox.SandboxCompleted(result) ->
          result
          |> should
          |> be_equal(AssertionOk)
          |> or_fail_with("should return AssertionOk")
        other ->
          Ok(
            AssertionFailed(AssertionFailure(
              operator: "sandbox",
              message: "unexpected: " <> string.inspect(other),
              payload: None,
            )),
          )
      }
    }),

    it("returns SandboxTimedOut on timeout", fn() {
      let config =
        sandbox.SandboxConfig(timeout_ms: 5, show_crash_reports: False)
      case sandbox.run_isolated(config, block_forever, Nil) {
        sandbox.SandboxTimedOut -> Ok(AssertionOk)
        other ->
          Ok(
            AssertionFailed(AssertionFailure(
              operator: "sandbox",
              message: "expected timeout, got: " <> string.inspect(other),
              payload: None,
            )),
          )
      }
    }),

    it("reports a quiet worker that an exit signal stops as crashed", fn() {
      let config =
        sandbox.SandboxConfig(timeout_ms: 1000, show_crash_reports: False)
      sandbox.run_isolated(config, kill_self, Nil)
      |> should
      |> be_equal(sandbox.SandboxCrashed("killed"))
      |> or_fail_with(
        "an exit signal should give SandboxCrashed, not a timeout",
      )
    }),

    it("does not take the down message of an earlier worker", fn() {
      let config =
        sandbox.SandboxConfig(timeout_ms: 1000, show_crash_reports: True)
      let _ = sandbox.run_isolated(config, double, 1)
      process.sleep(10)
      sandbox.run_isolated(config, double, 2)
      |> should
      |> be_equal(sandbox.SandboxCompleted(4))
      |> or_fail_with("the second run should complete")
    }),

    it("default_config waits 5 seconds and hides crash reports", fn() {
      sandbox.default_config()
      |> should
      |> be_equal(sandbox.SandboxConfig(
        timeout_ms: 5000,
        show_crash_reports: False,
      ))
      |> or_fail_with("default_config should be 5000ms, quiet")
    }),

    it("with_crash_reports turns crash reports on", fn() {
      sandbox.with_crash_reports(sandbox.default_config())
      |> should
      |> be_equal(sandbox.SandboxConfig(
        timeout_ms: 5000,
        show_crash_reports: True,
      ))
      |> or_fail_with("with_crash_reports should set show_crash_reports")
    }),

    it("reports a quiet crash with its class and reason", fn() {
      let config =
        sandbox.SandboxConfig(timeout_ms: 1000, show_crash_reports: False)
      sandbox.run_isolated(config, erlang_error, atom.create("boom"))
      |> should
      |> be_equal(sandbox.SandboxCrashed("error:boom"))
      |> or_fail_with("a quiet crash should give error:boom")
    }),

    it("reports an abnormal exit with crash reports on", fn() {
      let config =
        sandbox.SandboxConfig(timeout_ms: 1000, show_crash_reports: True)
      sandbox.run_isolated(config, exit_abnormally, "boom")
      |> should
      |> be_equal(sandbox.SandboxCrashed("\"boom\""))
      |> or_fail_with("an abnormal exit should give its reason")
    }),

    it("reports a normal exit before a result as crashed", fn() {
      let config =
        sandbox.SandboxConfig(timeout_ms: 1000, show_crash_reports: True)
      sandbox.run_isolated(config, exit_normally, Nil)
      |> should
      |> be_equal(sandbox.SandboxCrashed("normal"))
      |> or_fail_with("a normal exit before a result should give normal")
    }),

    it("passes its input to the function with crash reports off", fn() {
      let config =
        sandbox.SandboxConfig(timeout_ms: 1000, show_crash_reports: False)
      sandbox.run_isolated(config: config, run: double, input: 21)
      |> should
      |> be_equal(sandbox.SandboxCompleted(42))
      |> or_fail_with("the function should get the input 21")
    }),

    it("passes its input to the function with crash reports on", fn() {
      let config =
        sandbox.SandboxConfig(timeout_ms: 1000, show_crash_reports: True)
      sandbox.run_isolated(config: config, run: double, input: 4)
      |> should
      |> be_equal(sandbox.SandboxCompleted(8))
      |> or_fail_with("the function should get the input 4")
    }),

    it("format_exit_reason shows a normal exit as normal", fn() {
      process.Normal
      |> sandbox.format_exit_reason
      |> should
      |> be_equal("normal")
      |> or_fail_with("a normal exit should give normal")
    }),

    it("format_exit_reason shows a killed process as killed", fn() {
      process.Killed
      |> sandbox.format_exit_reason
      |> should
      |> be_equal("killed")
      |> or_fail_with("a killed process should give killed")
    }),

    it("format_exit_reason shows an abnormal reason as Gleam text", fn() {
      process.Abnormal(dynamic.string("boom"))
      |> sandbox.format_exit_reason
      |> should
      |> be_equal("\"boom\"")
      |> or_fail_with("an abnormal exit should give the quoted reason")
    }),

    it("run_catching returns the value of a function that returns", fn() {
      sandbox.run_catching(double, 61)
      |> should
      |> be_equal(Ok(122))
      |> or_fail_with("run_catching should return Ok(122)")
    }),

    it("run_catching returns the crash of a function that crashes", fn() {
      sandbox.run_catching(erlang_error, atom.create("boom"))
      |> should
      |> be_equal(Error("error:boom"))
      |> or_fail_with("run_catching should return the crash reason")
    }),

    it("run_catching runs the function in the calling process", fn() {
      sandbox.run_catching(own_pid, Nil)
      |> should
      |> be_equal(Ok(process.self()))
      |> or_fail_with("run_catching should not start a process")
    }),
  ])
}

/// Never return, so the sandbox can only time out.
fn block_forever(_input: Nil) -> AssertionResult {
  process.sleep_forever()
  AssertionOk
}

fn kill_self(_input: Nil) -> Nil {
  process.kill(process.self())
  process.sleep(5000)
}

fn exit_abnormally(reason: String) -> Nil {
  process.send_abnormal_exit(process.self(), reason)
  process.sleep(5000)
}

fn exit_normally(_input: Nil) -> Nil {
  process.send_exit(process.self())
  process.sleep(5000)
}

fn double(number: Int) -> Int {
  number * 2
}

@external(erlang, "erlang", "error")
fn erlang_error(reason: Atom) -> Nil

fn own_pid(_input: Nil) -> process.Pid {
  process.self()
}
