import dream_test/coverage.{type CoverageConfig}

pub fn write_markdown_table() -> CoverageConfig {
  coverage.new()
  |> coverage.markdown_path("build/coverage/coverage.md")
}
