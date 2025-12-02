//// README: Sequential execution for shared resources

import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporter/bdd.{report}
import dream_test/runner.{RunnerConfig, run_all_with_config}
import dream_test/unit.{describe, it, to_test_cases}
import gleam/io

pub fn tests() {
  describe("Sequential tests", [
    it("first test", fn() {
      // When tests share external resources, run them sequentially
      1 + 1
      |> should()
      |> equal(2)
      |> or_fail_with("Math works")
    }),
    it("second test", fn() {
      2 + 2
      |> should()
      |> equal(4)
      |> or_fail_with("Math still works")
    }),
  ])
}

pub fn main() {
  // Sequential execution for tests with shared state
  let config = RunnerConfig(max_concurrency: 1, default_timeout_ms: 30_000)

  to_test_cases("sequential_test", tests())
  |> run_all_with_config(config, _)
  |> report(io.print)
}
