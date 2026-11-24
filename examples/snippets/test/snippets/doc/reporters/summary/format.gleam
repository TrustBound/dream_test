import dream_test/reporters/summary
import dream_test/types.{type RunReport}

pub fn summary_line_with_skipped(report: RunReport) -> String {
  summary.format(report)
  // -> "Summary: 4 run, 1 failed, 2 passed, 1 skipped in 12ms\n"
}
