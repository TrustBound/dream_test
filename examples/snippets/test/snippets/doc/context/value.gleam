import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import dream_test/unit_context.{describe, it}

fn is_empty(items: List(String)) -> Result(AssertionResult, String) {
  items
  |> should
  |> be_equal([])
  |> or_fail_with("expected an empty cart")
}

pub fn cart_suite() -> TestSuite {
  describe("Cart", context.value([]), [it("starts empty", is_empty)])
}
