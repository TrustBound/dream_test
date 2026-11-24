import dream_test/coverage/json_summary.{type Options}

pub fn file_minimum_of_fifty() -> Options {
  json_summary.options()
  |> json_summary.minimum_percent_per_file(50.0)
}
