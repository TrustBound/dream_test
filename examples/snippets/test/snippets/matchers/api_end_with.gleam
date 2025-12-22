import dream_test/matchers.{end_with, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  "hello.gleam"
  |> should
  |> end_with(".gleam")
  |> or_fail_with("expected .gleam suffix")
}

pub fn tests() {
  describe("matchers.end_with", [
    it("checks the end of a string", fn() { example() }),
  ])
}
