//// The "Do" example of rule 2 of STANDARDS.md: the limit is a parameter.

import dream_test/matchers.{be_true, or_fail_with, should}
import dream_test/unit.{describe, it}

pub fn is_less_than(limit, value) {
  value < limit
}

pub fn tests() {
  describe("STANDARDS.md rule 2, Do: an explicit parameter", [
    it("checks a value with the limit parameter", fn() {
      // Act
      let result = is_less_than(5, 3)

      // Assert
      result
      |> should
      |> be_true()
      |> or_fail_with("3 should be below the limit 5")
    }),
  ])
}
