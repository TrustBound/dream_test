import dream_test/coverage/cobertura
import dream_test/coverage/report

pub fn empty_report_xml() -> String {
  cobertura.render(report: report.new([]), timestamp: 0)
}
