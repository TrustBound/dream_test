import dream_test/matchers.{contain_string, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  "hello world"
  |> should
  |> contain_string("world")
  |> or_fail_with("expected substring 'world'")
}

pub fn tests() {
  describe("matchers.contain_string", [
    it("checks a string contains a substring", fn() { example() }),
  ])
}
