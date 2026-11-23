import dream_test/reporters/summary
import dream_test/types.{type RunReport}
import gleam/io

pub fn print_summary_in_color(report: RunReport) -> Nil {
  io.print(summary.format_in_color(report))
}
