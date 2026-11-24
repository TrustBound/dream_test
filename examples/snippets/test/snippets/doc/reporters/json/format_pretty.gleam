import dream_test/matchers.{succeed}
import dream_test/reporters/json
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}

pub fn example_suite() -> TestSuite {
  describe("Example Suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() -> String {
  let report = runner.new([example_suite()]) |> runner.run()
  json.format_pretty(report)
}
