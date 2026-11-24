import dream_test/coverage.{type CoverageError}
import dream_test/coverage/report.{type CoverageReport}

pub fn check_each_file_against_fifty_percent(
  coverage_report: CoverageReport,
) -> Result(Nil, CoverageError) {
  coverage.new()
  |> coverage.minimum_percent_per_file(50.0)
  |> coverage.check_minimum_per_file(coverage_report)
  // -> Error(FilesBelowMinimumPercent(minimum_percent: 50.0, files: [
  //      coverage.file_below_minimum(source_path: "src/app/cart.gleam",
  //        hit: 3, total: 10, lines_needed: 5),
  //    ]))
}
