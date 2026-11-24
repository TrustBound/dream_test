import dream_test/coverage/report

pub fn source_path_of_cart_file() -> String {
  report.file("src/app/cart.gleam", [])
  |> report.source_path()
  // -> "src/app/cart.gleam"
}
