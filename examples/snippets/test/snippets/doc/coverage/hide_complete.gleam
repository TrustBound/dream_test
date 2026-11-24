import dream_test/coverage.{type CoverageConfig}

pub fn hide_fully_covered_files() -> CoverageConfig {
  coverage.new()
  |> coverage.hide_complete()
}
