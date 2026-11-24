//// The "Don't" example of rule 4 of STANDARDS.md: the abbreviated name
//// `fs`. It compiles and works, but the name says little.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionFailure, type Status, Failed, Passed}
import dream_test/unit.{describe, it}

pub fn status_from_failures(fs: List(AssertionFailure)) -> Status {
  case fs {
    [] -> Passed
    _ -> Failed
  }
}

pub fn tests() {
  describe("STANDARDS.md rule 4, Don't: an abbreviated name", [
    it("gives Passed for no failures", fn() {
      // Act
      let status = status_from_failures([])

      // Assert
      status
      |> should
      |> be_equal(Passed)
      |> or_fail_with("no failures should give Passed")
    }),
  ])
}
