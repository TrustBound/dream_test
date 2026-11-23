import dream_test/coverage.{type FileBelowMinimum}

pub fn cart_below_minimum() -> FileBelowMinimum {
  coverage.file_below_minimum(
    source_path: "src/app/cart.gleam",
    hit: 3,
    total: 10,
    lines_needed: 5,
  )
}
