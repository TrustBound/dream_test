import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox.{
  SandboxCompleted, SandboxConfig, SandboxCrashed, SandboxTimedOut,
}
import dream_test/unit.{describe, it}

fn double(number: Int) -> Int {
  number * 2
}

fn loop_forever(_input: Nil) -> Nil {
  loop_forever(Nil)
}

fn crash(message: String) -> Int {
  panic as message
}

pub fn tests() {
  describe("Sandboxing", [
    it("run_isolated returns SandboxCompleted(value) on success", fn() {
      let config = SandboxConfig(timeout_ms: 60_000, show_crash_reports: False)
      let result = sandbox.run_isolated(config, double, 61)

      result
      |> should
      |> be_equal(SandboxCompleted(122))
      |> or_fail_with("expected SandboxCompleted(122)")
    }),

    it(
      "run_isolated returns SandboxTimedOut when the function is too slow",
      fn() {
        let config = SandboxConfig(timeout_ms: 10, show_crash_reports: False)
        let result = sandbox.run_isolated(config, loop_forever, Nil)

        result
        |> should
        |> be_equal(SandboxTimedOut)
        |> or_fail_with("expected SandboxTimedOut")
      },
    ),

    it("run_isolated returns SandboxCrashed when the function panics", fn() {
      let config = SandboxConfig(timeout_ms: 60_000, show_crash_reports: False)
      let result = sandbox.run_isolated(config, crash, "boom")

      let did_crash = case result {
        SandboxCrashed(_) -> True
        _ -> False
      }

      did_crash
      |> should
      |> be_equal(True)
      |> or_fail_with("expected SandboxCrashed(...)")
    }),
  ])
}
