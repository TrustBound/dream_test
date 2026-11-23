//// The "Don't" example of rule 3 of STANDARDS.md: an anonymous test body.
//// Test files may use it; library code under `src/` must not. The test
//// run runs this suite.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}

pub fn math_tests() -> TestSuite {
  describe("math", [
    it("adds numbers", fn() {
      1 + 2
      |> should
      |> be_equal(3)
      |> or_fail_with("1 + 2 should be 3")
    }),
  ])
}

pub fn tests() -> TestSuite {
  math_tests()
}
