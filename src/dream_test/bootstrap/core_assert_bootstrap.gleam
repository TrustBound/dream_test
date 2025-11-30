import dream_test/bootstrap/core_assert

/// Layer 0 bootstrap checks for `core_assert`.
///
/// Uses only raw `assert` to sanity-check the tiny assertion helpers.
/// This module is not part of the public API; it's just a safety net
/// while bootstrapping the framework.
pub fn main() {
  // equal succeeds when values match
  core_assert.equal(1, 1, "equal should not fail for equal integers")

  // is_true succeeds when condition is true
  core_assert.is_true(True, "is_true should not fail for True")

}
