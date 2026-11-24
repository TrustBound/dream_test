import dream_test/coverage.{type CoverageError}
import dream_test/coverage/report.{type CoverageReport}

pub fn check_total_against_eighty_percent(
  coverage_report: CoverageReport,
) -> Result(Nil, CoverageError) {
  coverage.new()
  |> coverage.minimum_percent(80.0)
  |> coverage.check_minimum(coverage_report)
  // -> Error(BelowMinimumPercent(hit: 1567, total: 2230,
  //      minimum_percent: 80.0, lines_needed: 1784))
}
