//// The "Don't" example of rule 2 of STANDARDS.md: a closure that captures
//// `limit`. It compiles and works, but it hides the dependency.

import dream_test/matchers.{be_true, or_fail_with, should}
import dream_test/unit.{describe, it}

fn make_checker(limit) {
  fn(value) { value < limit }
}

pub fn tests() {
  describe("STANDARDS.md rule 2, Don't: a closure", [
    it("checks a value with the captured limit", fn() {
      // Arrange
      let is_below_five = make_checker(5)

      // Act
      let result = is_below_five(3)

      // Assert
      result
      |> should
      |> be_true()
      |> or_fail_with("3 should be below the captured limit 5")
    }),
  ])
}
