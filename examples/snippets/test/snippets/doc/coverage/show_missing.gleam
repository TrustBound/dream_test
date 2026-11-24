import dream_test/coverage.{type CoverageConfig}

pub fn list_missing_lines() -> CoverageConfig {
  coverage.new()
  |> coverage.show_missing()
}
