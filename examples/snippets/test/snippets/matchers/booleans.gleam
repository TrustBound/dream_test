import dream_test/matchers.{be_false, be_true, or_fail_with, should}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Matchers: booleans", [
    it("be_true passes for True", fn() {
      True
      |> should
      |> be_true()
      |> or_fail_with("expected True")
    }),
    it("be_false passes for False", fn() {
      False
      |> should
      |> be_false()
      |> or_fail_with("expected False")
    }),
  ])
}
