import dream_test/coverage/html
import dream_test/coverage/report.{LineCoverage}
import gleam/dict

pub fn combined_page() -> String {
  let coverage_report =
    report.new([
      report.file("src/a.gleam", [LineCoverage(line: 1, calls: 1)]),
    ])
  html.combined(
    report: coverage_report,
    sources: dict.from_list([#("src/a.gleam", "pub fn a() { 1 }\n")]),
  )
  // -> "<!DOCTYPE html>\n<html lang=\"en\">\n..."
}
