import dream_test/coverage/format
import dream_test/coverage/report
import gleam/option.{type Option}

pub fn nothing_was_excluded() -> Option(String) {
  report.new([])
  |> format.excluded_summary()
  // -> None
}
