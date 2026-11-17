//// Fixture for the coverage:ignore-function tests. The expected line
//// numbers in test/dream_test/coverage_ignore_test.gleam come from this
//// file, so update them when you change it.

// coverage:ignore-function only old callers use it
/// Doc comment between the marker and the function.
@deprecated("Use convert instead")
pub fn convert_legacy(number: Int) -> String {
  case number {
    0 -> "{"
    _ -> "}"
  }
}

pub fn convert(number: Int) -> Int {
  number + 1
}
