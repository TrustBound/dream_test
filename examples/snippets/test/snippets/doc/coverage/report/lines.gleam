import dream_test/coverage/report.{type LineCoverage, LineCoverage}

pub fn lines_of_file() -> List(LineCoverage) {
  report.file("src/a.gleam", [LineCoverage(line: 3, calls: 1)])
  |> report.lines()
  // -> [LineCoverage(line: 3, calls: 1)]
}
