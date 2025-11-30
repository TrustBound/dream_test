/// Minimal internal assertions used to bootstrap the rest of the framework.
///
/// This module intentionally has **no dependencies** on our test runner or
/// assertion engine. It only uses Gleam's built-in `assert` so that we have
/// a tiny, stable foundation to test core types and helpers.

pub fn equal(expected: a, actual: a, message: String) {
  assert expected == actual as message
}

pub fn is_true(condition: Bool, message: String) {
  assert condition as message
}
