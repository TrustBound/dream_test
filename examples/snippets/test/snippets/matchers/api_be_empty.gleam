import dream_test/matchers.{be_empty, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  []
  |> should
  |> be_empty()
  |> or_fail_with("expected empty list")
}

pub fn tests() {
  describe("matchers.be_empty", [
    it("passes for an empty list", fn() { example() }),
  ])
}
