import dream_test/coverage.{type CoverageConfig}

pub fn merge_server_coverage() -> CoverageConfig {
  coverage.new()
  |> coverage.merge_lcov("build/coverage/servers/*.info")
}
