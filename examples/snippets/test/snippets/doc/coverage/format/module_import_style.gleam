import dream_test/coverage/format

pub fn all_lines_ran() -> String {
  format.percent(hit: 20, total: 20)
  // -> "100.0%"
}
