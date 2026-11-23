import dream_test/coverage/report.{type ExcludedFile}
import gleam/option.{Some}

pub fn generated_database_file() -> ExcludedFile {
  report.excluded_file(
    source_path: "src/app/generated/db.gleam",
    pattern: "src/app/generated/**",
    reason: Some("generated code"),
  )
}
