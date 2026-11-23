import dream_test/coverage/report
import gleam/option.{None}

pub fn excluded_path_is_generated_database() -> String {
  report.excluded_file(
    source_path: "src/app/generated/db.gleam",
    pattern: "src/app/generated/**",
    reason: None,
  )
  |> report.excluded_source_path()
  // -> "src/app/generated/db.gleam"
}
