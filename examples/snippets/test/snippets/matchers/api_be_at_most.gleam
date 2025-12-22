import dream_test/matchers.{be_at_most, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  10
  |> should
  |> be_at_most(10)
  |> or_fail_with("expected 10 to be at most 10")
}

pub fn tests() {
  describe("matchers.be_at_most", [
    it("checks an int is <= a maximum", fn() { example() }),
  ])
}
