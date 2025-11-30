import dream_test/bootstrap/assertions

/// Bootstrap checks for `dream_test/bootstrap/assertions`.
///
/// Uses only raw `assert` to sanity-check the tiny assertion helpers.
/// This module is not part of the public API; it's just a safety net
/// while bootstrapping the framework.
pub fn main() {
  // equal succeeds when values match
  assertions.equal(1, 1, "equal should not fail for equal integers")

  // is_true succeeds when condition is true
  assertions.is_true(True, "is_true should not fail for True")

}
