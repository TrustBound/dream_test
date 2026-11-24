import dream_test/matchers.{succeed}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it, pending}

fn adds_an_item() -> Result(AssertionResult, String) {
  Ok(succeed())
}

pub fn cart_suite() -> TestSuite {
  describe("Cart", [
    it("adds an item", adds_an_item),
    pending("removes an item"),
    pending("empties the cart"),
  ])
}
