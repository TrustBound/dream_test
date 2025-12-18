//// README: Execution mode (suite-first)

import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporter
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() {
  describe("Execution modes demo", [
    it("runs as a suite", fn() {
      1 + 1
      |> should()
      |> equal(2)
      |> or_fail_with("Math works")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporter.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
