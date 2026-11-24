import dream_test/coverage
import gleam/option.{type Option}

pub fn default_lcov_file() -> Option(String) {
  coverage.new()
  |> coverage.lcov_file()
  // -> Some("build/coverage/lcov.info")
}
