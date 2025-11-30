import dream_test/bootstrap/assertions
import gleam/option.{None}
import dream_test/types.{type AssertionFailure, AssertionFailure, Location, Passed, Failed, status_from_failures}

/// Bootstrap checks for core types using core_assert.
///
/// This is a small sanity-check module to ensure the basic behaviour of
/// Status, AssertionFailure, and status_from_failures before we build
/// higher layers on top.
pub fn main() {
  // status_from_failures: empty failures => Passed
  let empty_failures: List(AssertionFailure) = []
  let empty_status = status_from_failures(empty_failures)
  assertions.equal(Passed, empty_status, "Empty failures should yield Passed status")

  // status_from_failures: non-empty failures => Failed
  let failure = AssertionFailure(
    operator: "equal",
    message: "",
    location: Location("mod", "file.gleam", 10),
    payload: None,
  )

  let non_empty_failures = [failure]
  let non_empty_status = status_from_failures(non_empty_failures)
  assertions.equal(Failed, non_empty_status, "Non-empty failures should yield Failed status")
}
