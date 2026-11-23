import dream_test/reporters/summary
import dream_test/types.{type RunReport}

pub fn summary_line(report: RunReport) -> String {
  summary.format(report)
  // -> "Summary: 3 run, 1 failed, 2 passed in 12ms\n"
}
