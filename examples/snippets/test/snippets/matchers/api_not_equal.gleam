import dream_test/matchers.{not_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}
import snippets.{add}

pub fn example() -> Result(AssertionResult, String) {
  add(10, 3)
  |> should
  |> not_equal(3)
  |> or_fail_with("10 + 3 should not equal 3")
}

pub fn tests() {
  describe("matchers.not_equal", [
    it("asserts two values are different", fn() { example() }),
  ])
}
