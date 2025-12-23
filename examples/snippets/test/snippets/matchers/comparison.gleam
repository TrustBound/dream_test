import dream_test/matchers.{
  be_at_least, be_at_most, be_between, be_greater_than, be_greater_than_float,
  be_in_range, be_less_than, be_less_than_float, or_fail_with, should,
}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Matchers: comparison", [
    it("be_greater_than checks an int is greater than a minimum", fn() {
      10
      |> should
      |> be_greater_than(0)
      |> or_fail_with("expected 10 to be greater than 0")
    }),
    it("be_less_than checks an int is less than a maximum", fn() {
      10
      |> should
      |> be_less_than(100)
      |> or_fail_with("expected 10 to be less than 100")
    }),
    it("be_at_least checks an int is >= a minimum", fn() {
      10
      |> should
      |> be_at_least(10)
      |> or_fail_with("expected 10 to be at least 10")
    }),
    it("be_at_most checks an int is <= a maximum", fn() {
      10
      |> should
      |> be_at_most(10)
      |> or_fail_with("expected 10 to be at most 10")
    }),
    it("be_between checks an int is between two bounds", fn() {
      5
      |> should
      |> be_between(1, 10)
      |> or_fail_with("expected 5 to be between 1 and 10")
    }),
    it("be_in_range checks an int is within an inclusive range", fn() {
      10
      |> should
      |> be_in_range(0, 100)
      |> or_fail_with("expected 10 to be in range 0..100")
    }),
    it("be_greater_than_float checks a float is greater than a minimum", fn() {
      0.5
      |> should
      |> be_greater_than_float(0.0)
      |> or_fail_with("expected 0.5 to be greater than 0.0")
    }),
    it("be_less_than_float checks a float is less than a maximum", fn() {
      0.5
      |> should
      |> be_less_than_float(1.0)
      |> or_fail_with("expected 0.5 to be less than 1.0")
    }),
  ])
}
