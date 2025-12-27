import dream_test/matchers.{or_fail_with, should}
import dream_test/matchers/comparison
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("dream_test/matchers/comparison", [
    it("be_greater_than passes for greater values", fn() {
      5
      |> should
      |> comparison.be_greater_than(3)
      |> or_fail_with("5 should be > 3")
    }),

    it("be_less_than passes for lesser values", fn() {
      5
      |> should
      |> comparison.be_less_than(10)
      |> or_fail_with("5 should be < 10")
    }),

    it("be_at_least passes for equal values", fn() {
      5
      |> should
      |> comparison.be_at_least(5)
      |> or_fail_with("5 should be >= 5")
    }),

    it("be_at_most passes for equal values", fn() {
      5
      |> should
      |> comparison.be_at_most(5)
      |> or_fail_with("5 should be <= 5")
    }),

    it("be_between passes for values inside inclusive bounds", fn() {
      5
      |> should
      |> comparison.be_between(1, 10)
      |> or_fail_with("5 should be between 1 and 10")
    }),

    it("be_in_range passes for values inside range", fn() {
      5
      |> should
      |> comparison.be_in_range(5, 6)
      |> or_fail_with("5 should be in range [5,6]")
    }),

    it("be_greater_than_float passes for greater float values", fn() {
      1.5
      |> should
      |> comparison.be_greater_than_float(1.0)
      |> or_fail_with("1.5 should be > 1.0")
    }),

    it("be_less_than_float passes for lesser float values", fn() {
      1.5
      |> should
      |> comparison.be_less_than_float(2.0)
      |> or_fail_with("1.5 should be < 2.0")
    }),
  ])
}
