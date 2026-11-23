import dream_test/coverage/format
import dream_test/coverage/report
import gleam/option.{Some}

pub fn debug_only_range_text() -> String {
  report.ignored_range(
    first_line: 40,
    last_line: 44,
    reason: Some("debug only"),
  )
  |> format.ignored_range()
  // -> "40-44 (debug only)"
}
