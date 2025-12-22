import dream_test/matchers.{be_greater_than, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  10
  |> should
  |> be_greater_than(0)
  |> or_fail_with("expected 10 to be greater than 0")
}

pub fn tests() {
  describe("matchers.be_greater_than", [
    it("checks an int is greater than a minimum", fn() { example() }),
  ])
}
