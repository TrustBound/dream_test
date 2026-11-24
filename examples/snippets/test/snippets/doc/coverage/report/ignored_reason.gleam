import dream_test/coverage/report
import gleam/option.{type Option, Some}

pub fn range_reason_is_debug_only() -> Option(String) {
  report.ignored_range(
    first_line: 40,
    last_line: 44,
    reason: Some("debug only"),
  )
  |> report.ignored_reason()
  // -> Some("debug only")
}
