import dream_test/matchers.{succeed}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type TestResult}
import dream_test/unit.{describe, it}

fn example_suite() -> TestSuite {
  describe("Example", [it("passes", fn() { Ok(succeed()) })])
}

pub fn read_the_test_results() -> List(TestResult) {
  runner.new([example_suite()])
  |> runner.run()
  |> types.report_tests
}
