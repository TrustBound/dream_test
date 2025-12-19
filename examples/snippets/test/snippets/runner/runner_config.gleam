//// README: Runner config

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() {
  describe("Runner config demo", [
    it("runs with custom config", fn() {
      1 + 1
      |> should
      |> be_equal(2)
      |> or_fail_with("Math works")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.max_concurrency(8)
  |> runner.default_timeout_ms(10_000)
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
