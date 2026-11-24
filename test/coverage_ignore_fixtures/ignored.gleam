//// Fixture for the ignore marker tests. The expected line numbers in
//// test/dream_test/coverage_ignore_test.gleam come from this file, so update
//// them when you change it.

pub fn describe(number: Int) -> String {
  case number {
    0 -> "zero"
    // coverage:ignore only old callers pass 1
    1 -> "one"
    _ -> "many"
  }
}

// coverage:ignore-start debug helper
pub fn debug(number: Int) -> Int {
  number + 1
}
// coverage:ignore-end
