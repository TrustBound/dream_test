import dream_test/reporters/diff.{type DiffLine}

pub fn one_changed_line() -> List(DiffLine) {
  diff.lines(expected: "a\nb\nc", actual: "a\nB\nc")
  // -> [Same("a"), Removed("b"), Added("B"), Same("c")]
}
