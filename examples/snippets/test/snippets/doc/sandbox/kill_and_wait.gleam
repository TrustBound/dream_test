import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/erlang/process

pub fn tests() -> TestSuite {
  describe("kill_and_wait", [
    it("returns when the process is gone", fn() {
      let pid = process.spawn_unlinked(process.sleep_forever)
      sandbox.kill_and_wait(pid)

      process.is_alive(pid)
      |> should
      |> be_equal(False)
      |> or_fail_with("expected the process to be gone")
    }),
  ])
}
