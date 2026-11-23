import dream_test/coverage/report.{type IgnoredRange}
import gleam/option.{None}

pub fn ignored_ranges_of_cart_file() -> List(IgnoredRange) {
  report.file("src/app/cart.gleam", [])
  |> report.add_ignored_ranges([
    report.ignored_range(first_line: 71, last_line: 71, reason: None),
  ])
  |> report.ignored_ranges()
  // -> [report.ignored_range(first_line: 71, last_line: 71, reason: None)]
}
