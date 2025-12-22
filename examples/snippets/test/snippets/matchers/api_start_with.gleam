import dream_test/matchers.{or_fail_with, should, start_with}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  "hello world"
  |> should
  |> start_with("hello")
  |> or_fail_with("expected string to start with 'hello'")
}

pub fn tests() {
  describe("matchers.start_with", [
    it("checks the start of a string", fn() { example() }),
  ])
}
