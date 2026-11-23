import dream_test/coverage.{type CoverageConfig}

pub fn require_a_reason_for_each_exclusion() -> CoverageConfig {
  coverage.new()
  |> coverage.exclude_with_reason(
    pattern: "src/app/generated/**",
    reason: "generated code",
  )
  |> coverage.require_exclusion_reasons()
}
