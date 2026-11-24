import dream_test/matchers.{succeed}
import dream_test/suite.{type TestSuite}
import dream_test/unit

pub fn tests() -> TestSuite {
  unit.describe("Cart", [unit.it("is empty", fn() { Ok(succeed()) })])
}

pub fn cart_suite_with_source() -> TestSuite {
  suite.with_source(suite: tests(), source: "cart_test")
}
