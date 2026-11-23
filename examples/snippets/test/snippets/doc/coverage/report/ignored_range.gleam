import dream_test/coverage/report.{type IgnoredRange}
import gleam/option.{Some}

pub fn debug_only_range() -> IgnoredRange {
  report.ignored_range(
    first_line: 40,
    last_line: 44,
    reason: Some("debug only"),
  )
}
