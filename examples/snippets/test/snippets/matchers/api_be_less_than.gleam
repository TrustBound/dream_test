import dream_test/matchers.{be_less_than, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  10
  |> should
  |> be_less_than(100)
  |> or_fail_with("expected 10 to be less than 100")
}

pub fn tests() {
  describe("matchers.be_less_than", [
    it("checks an int is less than a maximum", fn() { example() }),
  ])
}
