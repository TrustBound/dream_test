import dream_test/coverage.{type CoverageConfig}

pub fn exclude_generated_code_with_reason() -> CoverageConfig {
  coverage.new()
  |> coverage.exclude_with_reason(
    pattern: "src/app/generated/**",
    reason: "generated from the database schema",
  )
}
