import dream_test/coverage/json_summary

pub fn eighty_percent_minimum() -> json_summary.Options {
  json_summary.options()
  |> json_summary.minimum_percent(80.0)
}
