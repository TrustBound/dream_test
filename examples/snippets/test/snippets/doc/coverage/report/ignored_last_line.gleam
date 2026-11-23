import dream_test/coverage/report
import gleam/option.{None}

pub fn range_ends_at_line_forty_four() -> Int {
  report.ignored_range(first_line: 40, last_line: 44, reason: None)
  |> report.ignored_last_line()
  // -> 44
}
