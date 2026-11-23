import dream_test/reporters/ansi

pub fn red_line_numbers() -> String {
  ansi.red("12-13")
  // -> "\u{1b}[31m12-13\u{1b}[0m"
}
