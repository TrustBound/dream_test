import dream_test/coverage.{type CoverageConfig}

pub fn require_eighty_percent() -> CoverageConfig {
  coverage.new()
  |> coverage.minimum_percent(80.0)
}
