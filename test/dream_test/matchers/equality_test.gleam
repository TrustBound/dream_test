import dream_test/matchers.{or_fail_with, should}
import dream_test/matchers/equality
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("dream_test/matchers/equality", [
    it("equal passes for equal values", fn() {
      1
      |> should
      |> equality.be_equal(1)
      |> or_fail_with("1 should equal 1")
    }),

    it("not_equal passes for different values", fn() {
      1
      |> should
      |> equality.not_equal(2)
      |> or_fail_with("1 should not equal 2")
    }),
  ])
}
