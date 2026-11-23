import dream_test/coverage.{type CoverageConfig}

pub fn write_job_summary(summary_path: String) -> CoverageConfig {
  coverage.new()
  |> coverage.markdown_path(summary_path)
}
