import dream_test/reporters/ansi

pub fn magenta_skipped() -> String {
  ansi.magenta("Skipped")
  // -> "\u{1b}[35mSkipped\u{1b}[0m"
}
