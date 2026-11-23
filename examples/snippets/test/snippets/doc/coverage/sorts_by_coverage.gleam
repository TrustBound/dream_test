import dream_test/coverage

pub fn sort_by_coverage_is_on() -> Bool {
  coverage.new()
  |> coverage.sort_by_coverage()
  |> coverage.sorts_by_coverage()
  // -> True
}
