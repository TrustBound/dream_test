import dream_test/reporters/ansi

pub fn yellow_percent() -> String {
  ansi.yellow("90.0%")
  // -> "\u{1b}[33m90.0%\u{1b}[0m"
}
