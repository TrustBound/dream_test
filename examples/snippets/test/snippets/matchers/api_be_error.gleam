import dream_test/matchers.{be_equal, be_error, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  Error("nope")
  |> should
  |> be_error()
  |> be_equal("nope")
  |> or_fail_with("Should be Error(\"nope\")")
}

pub fn tests() {
  describe("matchers.be_error", [
    it("unwraps Error(value) so you can keep matching", fn() { example() }),
  ])
}
