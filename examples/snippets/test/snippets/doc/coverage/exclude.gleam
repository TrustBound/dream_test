import dream_test/coverage.{type CoverageConfig}

pub fn exclude_generated_and_ffi_files() -> CoverageConfig {
  coverage.new()
  |> coverage.exclude("src/app/generated/**")
  |> coverage.exclude("src/**/*_ffi.erl")
}
