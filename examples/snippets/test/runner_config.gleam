//// README: Runner config

import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporter/api as reporter
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() {
  describe("Runner config demo", [
    it("runs with custom config", fn(_) {
      1 + 1
      |> should()
      |> equal(2)
      |> or_fail_with("Math works")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.max_concurrency(8)
  |> runner.default_timeout_ms(10_000)
  |> runner.reporter(reporter.bdd(io.print, True))
  |> runner.run()
  |> runner.exit_results_on_failure
}
