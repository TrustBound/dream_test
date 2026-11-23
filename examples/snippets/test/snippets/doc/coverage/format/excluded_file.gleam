import dream_test/coverage/format
import dream_test/coverage/report
import gleam/option.{Some}

pub fn generated_file_text() -> String {
  report.excluded_file(
    source_path: "src/app/generated/db.gleam",
    pattern: "src/app/generated/**",
    reason: Some("generated code"),
  )
  |> format.excluded_file()
  // -> "excluded: matches src/app/generated/** (generated code)"
}
