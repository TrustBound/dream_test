import dream_test/coverage.{type CoverageConfig}

pub fn print_missing_lines_in_colour() -> CoverageConfig {
  coverage.new()
  |> coverage.show_missing()
  |> coverage.color()
}
