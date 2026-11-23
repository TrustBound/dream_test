import dream_test/coverage/markdown
import dream_test/coverage/report

pub fn empty_table() -> String {
  markdown.render(report.new([]))
}
