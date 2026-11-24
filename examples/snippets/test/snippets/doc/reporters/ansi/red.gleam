import dream_test/reporters/ansi

pub fn red_failed() -> String {
  ansi.red("Failed")
  // -> "\u{1b}[31mFailed\u{1b}[0m"
}
