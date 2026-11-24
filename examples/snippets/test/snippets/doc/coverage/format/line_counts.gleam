import dream_test/coverage/format

pub fn eighteen_of_twenty() -> String {
  format.line_counts(hit: 18, total: 20)
  // -> "18/20"
}
