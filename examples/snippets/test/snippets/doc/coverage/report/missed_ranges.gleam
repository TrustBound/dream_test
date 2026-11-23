import dream_test/coverage/report.{LineCoverage}

pub fn missed_ranges_of_file() -> List(#(Int, Int)) {
  report.file("src/a.gleam", [
    LineCoverage(line: 1, calls: 0),
    LineCoverage(line: 2, calls: 0),
    LineCoverage(line: 3, calls: 1),
    LineCoverage(line: 5, calls: 0),
  ])
  |> report.missed_ranges()
  // -> [#(1, 2), #(5, 5)]
}
