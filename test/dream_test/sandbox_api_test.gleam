import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox
import dream_test/types.{AssertionFailed, AssertionFailure, AssertionOk}
import dream_test/unit.{describe, it}
import gleam/erlang/process
import gleam/option.{None}
import gleam/string

pub fn tests() {
  describe("dream_test/sandbox", [
    it("returns SandboxCompleted on success", fn() {
      let config =
        sandbox.SandboxConfig(timeout_ms: 100, show_crash_reports: False)
      case sandbox.run_isolated(config, fn() { AssertionOk }) {
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
      case
        sandbox.run_isolated(config, fn() {
          process.sleep(50)
          AssertionOk
        })
      {
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
      sandbox.run_isolated(config, fn() {
        process.kill(process.self())
        process.sleep(5000)
      })
      |> should
      |> be_equal(sandbox.SandboxCrashed("killed"))
      |> or_fail_with(
        "an exit signal should give SandboxCrashed, not a timeout",
      )
    }),

    it("does not take the down message of an earlier worker", fn() {
      let config =
        sandbox.SandboxConfig(timeout_ms: 1000, show_crash_reports: True)
      let _ = sandbox.run_isolated(config, fn() { 1 })
      process.sleep(10)
      sandbox.run_isolated(config, fn() { 2 })
      |> should
      |> be_equal(sandbox.SandboxCompleted(2))
      |> or_fail_with("the second run should complete")
    }),
  ])
}
