import dream_test/matchers.{succeed}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}

pub fn unit_suite() -> TestSuite {
  describe("Unit", [
    it("adds", fn() { Ok(succeed()) }),
  ])
}

pub fn integration_suite() -> TestSuite {
  describe("Integration", [
    it("connects", fn() { Ok(succeed()) }),
  ])
}

pub fn run_unit_and_integration_suites() -> RunReport {
  runner.new([])
  |> runner.add_suites([unit_suite()])
  |> runner.add_suites([integration_suite()])
  |> runner.run()
}
