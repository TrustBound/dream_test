import dream_test/reporters/ansi

pub fn cyan_feature() -> String {
  ansi.cyan("Feature")
  // -> "\u{1b}[36mFeature\u{1b}[0m"
}
