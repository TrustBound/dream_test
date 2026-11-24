//// The "Do" example of rule 3 of STANDARDS.md: the test body is a named
//// function. The test run runs this suite.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn math_tests() -> TestSuite {
  describe("math", [
    it("adds numbers", adds_numbers_test),
  ])
}

fn adds_numbers_test() -> Result(AssertionResult, String) {
  1 + 2
  |> should
  |> be_equal(3)
  |> or_fail_with("1 + 2 should be 3")
}

pub fn tests() -> TestSuite {
  math_tests()
}
