import dream_test/matchers.{not_contain, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  ["a", "b", "c"]
  |> should
  |> not_contain("d")
  |> or_fail_with("List should not contain 'd'")
}

pub fn tests() {
  describe("matchers.not_contain", [
    it("passes when the item is absent", fn() { example() }),
  ])
}
