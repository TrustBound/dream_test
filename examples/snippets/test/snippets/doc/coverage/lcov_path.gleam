import dream_test/coverage.{type CoverageConfig}

pub fn write_lcov_to_unit_file() -> CoverageConfig {
  coverage.new()
  |> coverage.lcov_path("build/coverage/unit.lcov")
}
