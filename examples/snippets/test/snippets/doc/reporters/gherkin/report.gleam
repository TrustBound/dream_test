import dream_test/matchers.{succeed}
import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() -> TestSuite {
  describe("Shopping Cart", [
    it("adds items", fn() { Ok(succeed()) }),
  ])
}

pub fn main() -> RunReport {
  let report = runner.new([tests()]) |> runner.run()
  gherkin_reporter.report(report, io.print)
}
