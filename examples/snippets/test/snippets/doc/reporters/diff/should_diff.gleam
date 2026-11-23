import dream_test/reporters/diff

pub fn two_lines_show_as_a_diff() -> Bool {
  diff.should_diff(expected: "a\nb", actual: "a\nc")
  // -> True
}

pub fn one_line_shows_as_two_lines() -> Bool {
  diff.should_diff(expected: "1", actual: "2")
  // -> False
}
