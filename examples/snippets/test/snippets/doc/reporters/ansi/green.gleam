import dream_test/reporters/ansi

pub fn green_percent() -> String {
  ansi.green("100.0%")
  // -> "\u{1b}[32m100.0%\u{1b}[0m"
}
