import dream_test/coverage/format

pub fn lines_twelve_to_thirteen() -> String {
  format.line_range(first: 12, last: 13)
  // -> "12-13"
}
