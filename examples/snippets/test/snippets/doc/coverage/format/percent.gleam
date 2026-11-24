import dream_test/coverage/format

pub fn percent_rounds_down() -> String {
  format.percent(hit: 58, total: 60)
  // -> "96.6%"
}
