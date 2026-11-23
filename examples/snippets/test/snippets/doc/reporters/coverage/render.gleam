import dream_test/coverage
import dream_test/coverage/report.{LineCoverage}
import dream_test/reporters/coverage as coverage_reporter

pub fn table_of_one_file() -> String {
  let coverage_report =
    report.new([
      report.file("src/a.gleam", [
        LineCoverage(line: 1, calls: 1),
        LineCoverage(line: 2, calls: 0),
      ]),
    ])

  coverage_reporter.render(
    report: coverage_report,
    config: coverage.new() |> coverage.no_lcov(),
  )
  // -> "\nCoverage\nFile         Lines  Cover\nsrc/a.gleam  1/2    50.0%\nTotal        1/2    50.0%\n"
}
