import dream_test/matchers.{or_fail_with, should}
import dream_test/matchers/boolean
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("dream_test/matchers/boolean", [
    it("be_true passes for True", fn() {
      True
      |> should
      |> boolean.be_true()
      |> or_fail_with("True should be true")
    }),

    it("be_false passes for False", fn() {
      False
      |> should
      |> boolean.be_false()
      |> or_fail_with("False should be false")
    }),
  ])
}
