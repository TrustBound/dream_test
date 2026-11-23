import dream_test/coverage

pub fn color_is_on() -> Bool {
  coverage.new()
  |> coverage.color()
  |> coverage.uses_color()
  // -> True
}
