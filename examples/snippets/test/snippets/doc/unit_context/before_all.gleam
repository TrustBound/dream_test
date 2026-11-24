import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{before_all, describe, it}

pub fn suite() -> TestSuite {
  describe("Price list", context.value([]), [
    before_all(fn(_prices) { Ok([10, 20, 30]) }),
    it("has three prices", fn(prices: List(Int)) {
      prices
      |> should
      |> be_equal([10, 20, 30])
      |> or_fail_with("expected the prices that before_all loaded")
    }),
  ])
}
