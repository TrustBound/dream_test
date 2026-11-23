import dream_test/matchers.{succeed}
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}

pub fn tests() -> TestSuite {
  describe("Example", [
    it("works", fn() { Ok(succeed()) }),
  ])
}

pub fn my_report(report: RunReport) -> String {
  case types.failed(report) {
    True -> "My report: failed\n"
    False -> "My report: passed\n"
  }
}

pub fn main() -> RunReport {
  runner.new([tests()])
  |> runner.results_reporters([reporter_types.Custom(my_report)])
  |> runner.exit_on_failure()
  |> runner.run()
}
