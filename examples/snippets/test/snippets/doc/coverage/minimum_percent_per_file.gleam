import dream_test/coverage.{type CoverageConfig}

pub fn require_seventy_percent_in_each_file() -> CoverageConfig {
  coverage.new()
  |> coverage.minimum_percent(90.0)
  |> coverage.minimum_percent_per_file(70.0)
}
