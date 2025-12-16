//// README: Sequential execution for shared resources

import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporter/api as reporter
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() {
  describe("Sequential tests", [
    it("first test", fn(_) {
      // When tests share external resources, run them sequentially
      1 + 1
      |> should()
      |> equal(2)
      |> or_fail_with("Math works")
    }),
    it("second test", fn(_) {
      2 + 2
      |> should()
      |> equal(4)
      |> or_fail_with("Math still works")
    }),
  ])
}

pub fn main() {
  // Sequential execution for tests with shared state
  runner.new([tests()])
  |> runner.max_concurrency(1)
  |> runner.default_timeout_ms(30_000)
  |> runner.reporter(reporter.bdd(io.print, True))
  |> runner.run()
  |> runner.exit_results_on_failure
}
