import dream_test/coverage.{type CoverageConfig}

pub fn list_lowest_coverage_first() -> CoverageConfig {
  coverage.new()
  |> coverage.sort_by_coverage()
}
