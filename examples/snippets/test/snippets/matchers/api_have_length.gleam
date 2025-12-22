import dream_test/matchers.{have_length, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  [1, 2, 3]
  |> should
  |> have_length(3)
  |> or_fail_with("expected list length 3")
}

pub fn tests() {
  describe("matchers.have_length", [
    it("checks the length of a list", fn() { example() }),
  ])
}
