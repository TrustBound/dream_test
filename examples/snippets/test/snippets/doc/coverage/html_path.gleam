import dream_test/coverage.{type CoverageConfig}

pub fn write_html_pages() -> CoverageConfig {
  coverage.new()
  |> coverage.html_path("build/coverage/html")
}
