import dream_test/matchers.{be_false, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  False
  |> should
  |> be_false()
  |> or_fail_with("expected False")
}

pub fn tests() {
  describe("matchers.be_false", [
    it("passes for False", fn() { example() }),
  ])
}
