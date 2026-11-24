import app/cart
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, group, it, pending, skip, with_tags}

pub fn tests() {
  describe("Cart", [
    group("total", [
      it("is 0 for an empty cart", fn() {
        cart.total([])
        |> should
        |> be_equal(0)
        |> or_fail_with("an empty cart should cost nothing")
      })
        |> with_tags(["smoke"]),
      it("adds the prices", fn() {
        cart.total([250, 1000, 99])
        |> should
        |> be_equal(1349)
        |> or_fail_with("the total should be the sum of the prices")
      }),
    ]),
    group("discounts", [
      pending("takes 10% off above 100.00"),
      pending("never goes below 0"),
    ]),
    group("checkout", [
      skip("charges the card", fn() {
        cart.total([1000])
        |> should
        |> be_equal(1000)
        |> or_fail_with("the card should be charged the total")
      }),
    ])
      |> with_tags(["integration"]),
  ])
}
