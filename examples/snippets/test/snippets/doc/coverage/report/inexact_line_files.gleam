import dream_test/coverage/report

pub fn inexact_line_files_of_report() -> List(String) {
  report.new([])
  |> report.add_inexact_line_files(["src/app/cart.gleam"])
  |> report.inexact_line_files()
  // -> ["src/app/cart.gleam"]
}
