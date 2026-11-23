import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/summary
import dream_test/runner
import dream_test/types.{type RunReport}
import dream_test/unit.{before_all, describe, it}
import gleam/erlang/process

/// A suite whose `before_all` hook waits longer than the timeout.
pub fn slow_setup_tests() {
  describe("Search index", [
    before_all(fn() {
      process.sleep(1000)
      Ok(Nil)
    }),
    it("finds a document", fn() { Ok(succeed()) }),
  ])
}

pub fn run_with_a_short_timeout() -> RunReport {
  runner.new([slow_setup_tests()])
  |> runner.default_timeout_ms(200)
  |> runner.silent()
  |> runner.run()
}

pub fn tests() {
  describe("A setup hook slower than the timeout", [
    it("gives SetupFailed", fn() {
      // Act
      let report = run_with_a_short_timeout()

      // Assert
      summary.count(report).setup_failed
      |> should
      |> be_equal(1)
      |> or_fail_with("the test should be SetupFailed")
    }),
  ])
}
