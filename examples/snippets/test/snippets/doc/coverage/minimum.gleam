import dream_test/coverage
import gleam/option.{type Option}

pub fn minimum_is_eighty() -> Option(Float) {
  coverage.new()
  |> coverage.minimum_percent(80.0)
  |> coverage.minimum()
  // -> Some(80.0)
}
