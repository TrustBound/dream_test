import dream_test/coverage

pub fn cart_hit_lines() -> Int {
  coverage.file_below_minimum(
    source_path: "src/app/cart.gleam",
    hit: 3,
    total: 10,
    lines_needed: 5,
  )
  |> coverage.below_minimum_hit()
  // -> 3
}
