import dream_test/coverage.{type CoverageError}
import dream_test/reporters/coverage as coverage_reporter
import gleam/io
import gleam/result

pub fn print_coverage_table(
  run_my_tests: fn() -> Nil,
) -> Result(Nil, CoverageError) {
  let config = coverage.new()
  use session <- result.try(coverage.start(config))
  run_my_tests()
  use coverage_report <- result.map(coverage.finish(session))
  io.print(coverage_reporter.render(report: coverage_report, config: config))
}
