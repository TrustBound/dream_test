import dream_test/matchers.{contain, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  [1, 2, 3]
  |> should
  |> contain(2)
  |> or_fail_with("List should contain 2")
}

pub fn tests() {
  describe("matchers.contain", [
    it("passes when the item is present", fn() { example() }),
  ])
}
