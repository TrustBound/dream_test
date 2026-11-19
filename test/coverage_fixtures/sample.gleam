//// Fixture for the coverage tests. The expected line numbers in
//// test/dream_test/coverage_api_test.gleam and
//// test/dream_test/runner_coverage_test.gleam come from this file, so update
//// them when you change it.

pub fn classify(number: Int) -> String {
  case number > 0 {
    True -> "positive"
    False -> "not positive"
  }
}

pub fn never_called() -> Int {
  42
}
