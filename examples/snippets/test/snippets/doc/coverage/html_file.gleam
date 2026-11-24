import dream_test/coverage.{type CoverageConfig}

pub fn write_one_html_page() -> CoverageConfig {
  coverage.new()
  |> coverage.html_file("build/coverage/all.html")
}
