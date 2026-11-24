import dream_test/reporters/ansi

pub fn dim_duration() -> String {
  ansi.dim("12ms")
  // -> "\u{1b}[2m12ms\u{1b}[0m"
}
