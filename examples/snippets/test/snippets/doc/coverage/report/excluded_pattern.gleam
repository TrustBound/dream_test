import dream_test/coverage/report
import gleam/option.{None}

pub fn excluded_pattern_is_generated_folder() -> String {
  report.excluded_file(
    source_path: "src/app/generated/db.gleam",
    pattern: "src/app/generated/**",
    reason: None,
  )
  |> report.excluded_pattern()
  // -> "src/app/generated/**"
}
