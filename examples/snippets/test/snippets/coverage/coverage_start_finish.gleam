import dream_test/coverage
import dream_test/matchers.{contain_string, or_fail_with, should}
import dream_test/reporters/coverage as coverage_reporter
import dream_test/unit.{describe, it}
import snippets

pub fn tests() {
  describe("Coverage without the runner", [
    it("measures the code that runs between start and finish", fn() {
      coverage_table()
      |> should
      |> contain_string("src/snippets.gleam")
      |> or_fail_with("the table should list src/snippets.gleam")
    }),
  ])
}

fn coverage_table() -> String {
  let config =
    coverage.new()
    |> coverage.no_lcov()
  let assert Ok(session) = coverage.start(config)
  let _sum = snippets.add(1, 2)
  let assert Ok(coverage_report) = coverage.finish(session)
  coverage_reporter.render(report: coverage_report, config: config)
}
