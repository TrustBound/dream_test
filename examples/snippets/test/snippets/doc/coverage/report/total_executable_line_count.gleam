import dream_test/coverage/report.{LineCoverage}

pub fn executable_lines_in_all_files() -> Int {
  let cart_file =
    report.file("src/app/cart.gleam", [
      LineCoverage(line: 3, calls: 1),
      LineCoverage(line: 4, calls: 0),
    ])
  let types_file =
    report.file("src/app/types.gleam", [LineCoverage(line: 1, calls: 2)])
  report.new([cart_file, types_file])
  |> report.total_executable_line_count()
  // -> 3
}
