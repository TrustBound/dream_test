import dream_test/coverage/report.{type FileCoverage, LineCoverage}

pub fn files_of_report() -> List(FileCoverage) {
  let cart_file =
    report.file("src/app/cart.gleam", [LineCoverage(line: 3, calls: 1)])
  report.new([cart_file])
  |> report.files()
  // -> [cart_file]
}
