import dream_test/matchers.{be_less_than_float, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  0.5
  |> should
  |> be_less_than_float(1.0)
  |> or_fail_with("expected 0.5 to be less than 1.0")
}

pub fn tests() {
  describe("matchers.be_less_than_float", [
    it("checks a float is less than a maximum", fn() { example() }),
  ])
}
