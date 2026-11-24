import dream_test/coverage/report.{type CoverageReport, LineCoverage}
import gleam/option.{Some}

pub fn report_with_generated_file_excluded() -> CoverageReport {
  let cart_file =
    report.file("src/app/cart.gleam", [LineCoverage(line: 3, calls: 1)])
  report.new([cart_file])
  |> report.add_excluded_files([
    report.excluded_file(
      source_path: "src/app/generated/db.gleam",
      pattern: "src/app/generated/**",
      reason: Some("generated code"),
    ),
  ])
}
