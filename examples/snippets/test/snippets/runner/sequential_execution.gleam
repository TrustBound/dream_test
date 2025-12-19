//// README: Sequential execution for shared resources

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() {
  describe("Sequential tests", [
    it("first test", fn() {
      // When tests share external resources, run them sequentially
      1 + 1
      |> should
      |> be_equal(2)
      |> or_fail_with("Math works")
    }),
    it("second test", fn() {
      2 + 2
      |> should
      |> be_equal(4)
      |> or_fail_with("Math still works")
    }),
  ])
}

pub fn main() {
  // Sequential execution for tests with shared state
  runner.new([tests()])
  |> runner.max_concurrency(1)
  |> runner.default_timeout_ms(30_000)
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
