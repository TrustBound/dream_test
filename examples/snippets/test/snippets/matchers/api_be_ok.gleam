import dream_test/matchers.{be_equal, be_ok, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}

pub fn example() -> Result(AssertionResult, String) {
  Ok("success")
  |> should
  |> be_ok()
  |> be_equal("success")
  |> or_fail_with("Should be Ok with 'success'")
}

pub fn tests() {
  describe("matchers.be_ok", [
    it("unwraps Ok(value) so you can keep matching", fn() { example() }),
  ])
}
