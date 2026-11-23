import dream_test/coverage
import gleam/option.{type Option}

pub fn minimum_per_file_is_seventy() -> Option(Float) {
  coverage.new()
  |> coverage.minimum_percent_per_file(70.0)
  |> coverage.minimum_per_file()
  // -> Some(70.0)
}
