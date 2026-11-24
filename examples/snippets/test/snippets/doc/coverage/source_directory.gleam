import dream_test/coverage.{type CoverageConfig}

pub fn measure_the_app_folder() -> CoverageConfig {
  coverage.new()
  |> coverage.source_directory("src/app")
}
