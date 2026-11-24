import dream_test/coverage/report.{type ExcludedFile}
import gleam/option.{None}

pub fn excluded_files_of_report() -> List(ExcludedFile) {
  let generated_file =
    report.excluded_file(
      source_path: "src/app/generated/db.gleam",
      pattern: "src/app/generated/**",
      reason: None,
    )
  report.new([])
  |> report.add_excluded_files([generated_file])
  |> report.excluded_files()
  // -> [generated_file]
}
