import dream_test/reporters/ansi

pub fn red_when_enabled() -> String {
  ansi.apply_if(enabled: True, style: ansi.red, text: "Failed")
  // -> "\u{1b}[31mFailed\u{1b}[0m"
}

pub fn plain_when_disabled() -> String {
  ansi.apply_if(enabled: False, style: ansi.red, text: "Failed")
  // -> "Failed"
}
