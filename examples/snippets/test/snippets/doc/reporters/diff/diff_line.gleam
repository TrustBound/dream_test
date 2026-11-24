import dream_test/reporters/diff.{type DiffLine}

pub fn final_newline_lines() -> List(DiffLine) {
  diff.lines(expected: "a\nb\n", actual: "a\nb")
  // -> [Same("a"), Removed("b"), Added("b"), NoNewlineAtEnd]
}
