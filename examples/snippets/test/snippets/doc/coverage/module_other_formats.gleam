import dream_test/coverage.{type CoverageConfig}

pub fn write_every_format() -> CoverageConfig {
  coverage.new()
  |> coverage.json_path("build/coverage/coverage.json")
  |> coverage.cobertura_path("build/coverage/cobertura.xml")
  |> coverage.markdown_path("build/coverage/coverage.md")
  |> coverage.html_path("build/coverage/html")
  |> coverage.html_file("build/coverage/all.html")
}
