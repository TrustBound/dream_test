import dream_test/coverage.{type CoverageConfig}

pub fn write_cobertura_xml() -> CoverageConfig {
  coverage.new()
  |> coverage.cobertura_path("build/coverage/cobertura.xml")
}
