import dream_test/matchers.{be_equal, be_error, be_ok, or_fail_with, should}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Matchers: results", [
    it("be_ok unwraps Ok(value) so you can keep matching", fn() {
      Ok("hello")
      |> should
      |> be_ok()
      |> be_equal("hello")
      |> or_fail_with("expected Ok(\"hello\")")
    }),
    it("be_error unwraps Error(value) so you can keep matching", fn() {
      Error("nope")
      |> should
      |> be_error()
      |> be_equal("nope")
      |> or_fail_with("expected Error(\"nope\")")
    }),
  ])
}
