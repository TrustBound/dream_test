import dream_test/matchers.{be_true, fail_with, or_fail_with, should, succeed}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Matchers: getting started", [
    it("starts a matcher chain with should", fn() {
      True
      |> should
      |> be_true()
      |> or_fail_with("expected True")
    }),
    it("use succeed/fail_with in conditional branches", fn() {
      Ok(case 1 + 1 {
        2 -> succeed()
        _ -> fail_with("expected 1 + 1 to be 2")
      })
    }),
  ])
}
