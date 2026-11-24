import dream_test/coverage/report.{type CoverageReport, LineCoverage}

pub fn report_with_one_file() -> CoverageReport {
  report.new([
    report.file("src/app/cart.gleam", [LineCoverage(line: 3, calls: 1)]),
  ])
}
