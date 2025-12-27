import dream_test/matchers.{be_equal, be_none, be_some, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}

pub fn tests() {
  describe("Matchers: options", [
    it("be_some unwraps Some(value) so you can keep matching", fn() {
      Some(42)
      |> should
      |> be_some()
      |> be_equal(42)
      |> or_fail_with("expected Some(42)")
    }),
    it("be_none passes for None", fn() {
      None
      |> should
      |> be_none()
      |> or_fail_with("expected None")
    }),
  ])
}
