import dream_test/coverage/format
import dream_test/coverage/report.{LineCoverage}

pub fn missed_lines_of_file() -> List(String) {
  report.file("src/a.gleam", [
    LineCoverage(line: 12, calls: 0),
    LineCoverage(line: 13, calls: 0),
    LineCoverage(line: 20, calls: 0),
  ])
  |> format.missed_lines()
  // -> ["12-13", "20"]
}
