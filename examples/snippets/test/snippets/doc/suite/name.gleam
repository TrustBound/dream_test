import dream_test/suite
import dream_test/unit

pub fn cart_name() -> String {
  suite.name(unit.describe("Cart", []))
  // -> "Cart"
}
