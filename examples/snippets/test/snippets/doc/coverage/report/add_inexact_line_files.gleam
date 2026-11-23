import dream_test/coverage/report.{type CoverageReport, LineCoverage}

pub fn report_with_inexact_cart_lines() -> CoverageReport {
  let cart_file =
    report.file("src/app/cart.gleam", [LineCoverage(line: 3, calls: 1)])
  report.new([cart_file])
  |> report.add_inexact_line_files(["src/app/cart.gleam"])
}
