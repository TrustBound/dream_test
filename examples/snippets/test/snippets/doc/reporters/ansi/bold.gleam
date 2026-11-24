import dream_test/reporters/ansi

pub fn bold_failures() -> String {
  ansi.bold("Failures:")
  // -> "\u{1b}[1mFailures:\u{1b}[0m"
}
