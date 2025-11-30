import dream_test/bootstrap/core_assert
import dream_test/core/types

/// Bootstrap checks for core types using core_assert.
///
/// This is a small sanity-check module to ensure the basic behaviour of
/// Status, AssertionFailure, and status_from_failures before we build
/// higher layers on top.
pub fn main() {
  // status_from_failures: empty failures => Passed
  let empty_failures: List(types.AssertionFailure(Int)) = []
  let empty_status = types.status_from_failures(empty_failures)
  core_assert.equal(types.Passed, empty_status, "Empty failures should yield Passed status")

  // status_from_failures: non-empty failures => Failed
  let failure = types.AssertionFailure(
    actual: 1,
    expected: 2,
    operator: "equal",
    message: "",
    location: types.Location("mod", "file.gleam", 10),
  )

  let non_empty_failures = [failure]
  let non_empty_status = types.status_from_failures(non_empty_failures)
  core_assert.equal(types.Failed, non_empty_status, "Non-empty failures should yield Failed status")
}
