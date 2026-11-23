import dream_test/coverage.{type CoverageConfig}

pub fn write_json_summary() -> CoverageConfig {
  coverage.new()
  |> coverage.json_path("build/coverage/coverage.json")
}
