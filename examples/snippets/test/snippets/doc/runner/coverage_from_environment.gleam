import dream_test/coverage
import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}

pub fn tests() -> TestSuite {
  describe("Example", [
    it("works", fn() { Ok(succeed()) }),
  ])
}

pub fn main() -> RunReport {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.coverage_from_environment(coverage.new())
  |> runner.exit_on_failure()
  |> runner.run()
}
