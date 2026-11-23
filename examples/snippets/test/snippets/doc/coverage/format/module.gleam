import dream_test/coverage/format

pub fn ninety_percent() -> String {
  format.percent(hit: 18, total: 20)
  // -> "90.0%"
}
