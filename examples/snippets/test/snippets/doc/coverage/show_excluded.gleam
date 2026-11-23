import dream_test/coverage.{type CoverageConfig}

pub fn list_excluded_files_and_lines() -> CoverageConfig {
  coverage.new()
  |> coverage.show_excluded()
}
