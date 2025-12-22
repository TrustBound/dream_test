import dream_test/matchers.{be_true, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  True
  |> should
  |> be_true()
  |> or_fail_with("expected True")
}

pub fn tests() {
  describe("matchers.be_true", [
    it("passes for True", fn() { example() }),
  ])
}
