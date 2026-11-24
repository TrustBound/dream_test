import dream_test/coverage.{type CoverageConfig}

pub fn skip_the_lcov_file() -> CoverageConfig {
  coverage.new()
  |> coverage.no_lcov()
}
