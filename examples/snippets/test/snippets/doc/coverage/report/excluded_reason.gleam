import dream_test/coverage/report
import gleam/option.{type Option, Some}

pub fn excluded_reason_is_generated_code() -> Option(String) {
  report.excluded_file(
    source_path: "src/app/generated/db.gleam",
    pattern: "src/app/generated/**",
    reason: Some("generated code"),
  )
  |> report.excluded_reason()
  // -> Some("generated code")
}
