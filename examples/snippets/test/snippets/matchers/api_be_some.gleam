import dream_test/matchers.{be_equal, be_some, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}
import gleam/option.{Some}

pub fn example() -> Result(AssertionResult, String) {
  Some(42)
  |> should
  |> be_some()
  |> be_equal(42)
  |> or_fail_with("Should contain 42")
}

pub fn tests() {
  describe("matchers.be_some", [
    it("unwraps Some(value) so you can keep matching", fn() { example() }),
  ])
}
