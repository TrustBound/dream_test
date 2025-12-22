import dream_test/matchers.{be_none, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}
import gleam/option.{None}

pub fn example() -> Result(AssertionResult, String) {
  None
  |> should
  |> be_none()
  |> or_fail_with("expected None")
}

pub fn tests() {
  describe("matchers.be_none", [
    it("passes for None", fn() { example() }),
  ])
}
