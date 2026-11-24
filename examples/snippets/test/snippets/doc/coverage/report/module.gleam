import dream_test/coverage/report
import gleam/int
import gleam/io
import gleam/list

pub fn print_summary(coverage_report: report.CoverageReport) -> Nil {
  list.each(report.files(coverage_report), print_file)
}

fn print_file(file: report.FileCoverage) -> Nil {
  io.println(
    report.source_path(file)
    <> ": "
    <> int.to_string(report.hit_line_count(file))
    <> "/"
    <> int.to_string(report.executable_line_count(file)),
  )
}
