import dream_test/coverage
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe}

pub fn run_tests_with_default_coverage() -> RunReport {
  runner.new([tests()])
  |> runner.coverage(coverage.new())
  |> runner.run()
}

fn tests() -> TestSuite {
  describe("app", [])
}
