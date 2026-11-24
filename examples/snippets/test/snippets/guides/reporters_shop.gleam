//// A checkout suite with one test of each status but one, for the reports
//// that the guide on reporters shows. The suite is `shop_tests`, so test
//// discovery runs only `tests`, which checks the statuses.

import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/summary
import dream_test/runner
import dream_test/unit.{describe, group, it, pending, skip, with_tags}

pub fn shop_tests() {
  describe("Checkout", [
    it("totals the cart", fn() {
      1000 + 250
      |> should
      |> be_equal(1250)
      |> or_fail_with("the total should be 1250")
    })
      |> with_tags(["smoke"]),
    it("adds the tax", fn() {
      1250 * 120 / 100
      |> should
      |> be_equal(1525)
      |> or_fail_with("20% tax on 1250 should be 1525")
    }),
    group("payment", [
      skip("charges the card", fn() { Ok(succeed()) }),
      pending("refunds a cancelled order"),
    ]),
  ])
}

pub fn tests() {
  describe("The checkout suite", [
    it("has one failing test", fn() {
      // Act
      let report =
        runner.new([shop_tests()])
        |> runner.silent()
        |> runner.run()

      // Assert
      summary.count(report).failed
      |> should
      |> be_equal(1)
      |> or_fail_with("only the tax test should fail")
    }),
  ])
}
