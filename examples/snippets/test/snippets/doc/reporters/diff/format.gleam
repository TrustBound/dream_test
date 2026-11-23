import dream_test/reporters/diff

pub fn final_newline_diff() -> String {
  diff.format(expected: "a\nb\n", actual: "a\nb", indent: "", color: False)
  // -> "Diff (- expected, + actual):\n    a\n  - b\n  + b\n  \\ No newline at end of text\n"
}
