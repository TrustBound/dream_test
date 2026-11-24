import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/summary
import dream_test/runner
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}
import gleam/erlang/process

/// A suite with a test that hangs, as a call to a server that never
/// answers does.
pub fn search_tests() {
  describe("Search", [
    it("answers fast", fn() { Ok(succeed()) }),
    it("waits for an index that never comes", fn() {
      process.sleep(1000)
      Ok(succeed())
    }),
  ])
}

pub fn run_with_a_short_timeout() -> RunReport {
  runner.new([search_tests()])
  |> runner.default_timeout_ms(200)
  |> runner.silent()
  |> runner.run()
}

pub fn tests() {
  describe("A test slower than the timeout", [
    it("is TimedOut", fn() {
      // Act
      let report = run_with_a_short_timeout()

      // Assert
      summary.count(report).timed_out
      |> should
      |> be_equal(1)
      |> or_fail_with("the hanging test should time out")
    }),
  ])
}
