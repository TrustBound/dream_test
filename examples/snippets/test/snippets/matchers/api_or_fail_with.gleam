import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}
import snippets.{add}

pub fn example() -> Result(AssertionResult, String) {
  add(2, 3)
  |> should
  |> be_equal(5)
  |> or_fail_with("2 + 3 should equal 5")
}

pub fn tests() {
  describe("matchers.or_fail_with", [
    it("finishes a matcher chain and provides a message", fn() { example() }),
  ])
}
