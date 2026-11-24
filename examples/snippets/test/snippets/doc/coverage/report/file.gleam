import dream_test/coverage/report.{type FileCoverage, LineCoverage}

pub fn cart_file_with_sorted_lines() -> FileCoverage {
  report.file("src/app/cart.gleam", [
    LineCoverage(line: 4, calls: 0),
    LineCoverage(line: 3, calls: 2),
  ])
  // lines are stored as line 3, then line 4
}
