import dream_test/matchers.{fail_with, succeed}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}
import snippets.{add}

pub fn example() -> Result(AssertionResult, String) {
  Ok(case add(1, 1) {
    2 -> succeed()
    _ -> fail_with("expected 1 + 1 to be 2")
  })
}

pub fn tests() {
  describe("matchers.fail_with", [
    it("produces a failing AssertionResult", fn() { example() }),
  ])
}
