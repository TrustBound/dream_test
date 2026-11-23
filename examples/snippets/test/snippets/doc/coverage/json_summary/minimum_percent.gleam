import dream_test/coverage/json_summary.{type Options}

pub fn total_minimum_of_eighty() -> Options {
  json_summary.options()
  |> json_summary.minimum_percent(80.0)
}
