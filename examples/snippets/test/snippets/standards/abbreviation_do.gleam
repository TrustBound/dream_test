//// The "Do" example of rule 4 of STANDARDS.md: the full name `failures`.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionFailure, type Status, Failed, Passed}
import dream_test/unit.{describe, it}

pub fn status_from_failures(
  failures failures: List(AssertionFailure),
) -> Status {
  case failures {
    [] -> Passed
    _ -> Failed
  }
}

pub fn tests() {
  describe("STANDARDS.md rule 4, Do: a full name", [
    it("gives Passed for no failures", fn() {
      // Act
      let status = status_from_failures(failures: [])

      // Assert
      status
      |> should
      |> be_equal(Passed)
      |> or_fail_with("no failures should give Passed")
    }),
  ])
}
