import dream_test/matchers.{be_between, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  5
  |> should
  |> be_between(1, 10)
  |> or_fail_with("expected 5 to be between 1 and 10")
}

pub fn tests() {
  describe("matchers.be_between", [
    it("checks an int is between two bounds", fn() { example() }),
  ])
}
