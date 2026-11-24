import dream_test/coverage/json_summary
import dream_test/coverage/report.{type CoverageReport}

pub fn render_without_minimums(coverage_report: CoverageReport) -> String {
  json_summary.render(report: coverage_report, options: json_summary.options())
}
