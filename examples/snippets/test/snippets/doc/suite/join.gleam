import dream_test/matchers.{succeed}
import dream_test/suite.{type TestSuite}
import dream_test/unit

fn cart_suite() -> TestSuite {
  unit.describe("Cart", [unit.it("starts empty", fn() { Ok(succeed()) })])
}

fn payment_suite() -> TestSuite {
  unit.describe("Payment", [unit.it("takes a card", fn() { Ok(succeed()) })])
}

pub fn checkout_suite() -> TestSuite {
  suite.join(name: "checkout", suites: [cart_suite(), payment_suite()])
}
