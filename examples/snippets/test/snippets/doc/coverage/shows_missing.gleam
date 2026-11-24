import dream_test/coverage

pub fn show_missing_is_on() -> Bool {
  coverage.new()
  |> coverage.show_missing()
  |> coverage.shows_missing()
  // -> True
}
