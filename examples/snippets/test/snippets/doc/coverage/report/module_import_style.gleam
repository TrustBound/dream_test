import dream_test/coverage/report.{type CoverageReport, LineCoverage}

pub fn cart_report() -> CoverageReport {
  report.new([
    report.file("src/app/cart.gleam", [LineCoverage(line: 3, calls: 1)]),
  ])
}
