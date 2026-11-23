import dream_test/coverage/report.{LineCoverage}

pub fn two_lines_are_executable() -> Int {
  report.file("src/a.gleam", [
    LineCoverage(line: 1, calls: 3),
    LineCoverage(line: 2, calls: 0),
  ])
  |> report.executable_line_count()
  // -> 2
}
