import dream_test/reporters/summary
import dream_test/types.{type RunReport}

pub fn failed_count(report: RunReport) -> Int {
  let counts = summary.count(report)
  counts.failed
  // -> 1
}
