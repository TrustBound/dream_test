import dream_test/matchers.{succeed}
import dream_test/reporters/json
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}
import gleam/io

pub fn example_suite() -> TestSuite {
  describe("Example Suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() -> RunReport {
  let report = runner.new([example_suite()]) |> runner.run()
  report |> json.report_pretty(io.print)
}
