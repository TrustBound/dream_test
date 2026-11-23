import dream_test/coverage

pub fn show_excluded_is_on() -> Bool {
  coverage.new()
  |> coverage.show_excluded()
  |> coverage.shows_excluded()
  // -> True
}
