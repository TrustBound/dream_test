import dream_test/coverage

pub fn hide_complete_is_on() -> Bool {
  coverage.new()
  |> coverage.hide_complete()
  |> coverage.hides_complete()
  // -> True
}
