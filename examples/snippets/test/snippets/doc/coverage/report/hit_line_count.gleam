import dream_test/coverage/report.{LineCoverage}

pub fn one_line_was_hit() -> Int {
  report.file("src/a.gleam", [
    LineCoverage(line: 1, calls: 3),
    LineCoverage(line: 2, calls: 0),
  ])
  |> report.hit_line_count()
  // -> 1
}
