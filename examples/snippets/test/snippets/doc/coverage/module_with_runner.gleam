import dream_test/coverage
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe}

pub fn main() -> RunReport {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.coverage(
    coverage.new()
    |> coverage.show_missing()
    |> coverage.minimum_percent(80.0),
  )
  |> runner.exit_on_failure()
  |> runner.run()
}

fn tests() -> TestSuite {
  describe("app", [])
}
