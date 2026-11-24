import dream_test/reporters/hook_failures
import dream_test/types.{type RunReport}
import gleam/io

pub fn print_hook_failures_in_color(report: RunReport) -> Nil {
  io.print(hook_failures.format_in_color(types.report_hook_failures(report)))
}
