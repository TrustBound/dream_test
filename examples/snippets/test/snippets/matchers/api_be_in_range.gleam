import dream_test/matchers.{be_in_range, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  10
  |> should
  |> be_in_range(0, 100)
  |> or_fail_with("expected 10 to be in range 0..100")
}

pub fn tests() {
  describe("matchers.be_in_range", [
    it("checks an int is within an inclusive range", fn() { example() }),
  ])
}
