import dream_test/matchers.{be_equal, not_equal, or_fail_with, should}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Matchers: equality", [
    it("be_equal compares two values for equality", fn() {
      2 + 3
      |> should
      |> be_equal(5)
      |> or_fail_with("2 + 3 should equal 5")
    }),
    it("not_equal asserts two values are different", fn() {
      10 + 3
      |> should
      |> not_equal(3)
      |> or_fail_with("10 + 3 should not equal 3")
    }),
  ])
}
