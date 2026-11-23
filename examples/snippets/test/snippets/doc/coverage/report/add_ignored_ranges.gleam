import dream_test/coverage/report.{type FileCoverage, LineCoverage}
import gleam/option.{Some}

pub fn cart_file_with_debug_lines_ignored() -> FileCoverage {
  report.file("src/app/cart.gleam", [LineCoverage(line: 3, calls: 1)])
  |> report.add_ignored_ranges([
    report.ignored_range(
      first_line: 40,
      last_line: 44,
      reason: Some("debug only"),
    ),
  ])
}
