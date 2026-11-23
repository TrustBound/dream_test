//// The "Do" example of rule 6 of STANDARDS.md: pipe-first matchers.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn check(value: Int, expected: Int) -> Result(AssertionResult, String) {
  value
  |> should
  |> be_equal(expected)
  |> or_fail_with("message")
}

pub fn tests() {
  describe("STANDARDS.md rule 6, Do: pipe-first", [
    it("passes for equal values", fn() { check(3, 3) }),
  ])
}
