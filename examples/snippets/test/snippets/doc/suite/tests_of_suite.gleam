import dream_test/matchers.{succeed}
import dream_test/suite
import dream_test/types.{type AssertionResult}
import dream_test/unit
import gleam/list

fn is_empty() -> Result(AssertionResult, String) {
  Ok(succeed())
}

pub fn cart_test_names() -> List(String) {
  suite.tests(unit.describe("Cart", [unit.it("is empty", is_empty)]))
  |> list.map(fn(info) { info.name })
  // -> ["is empty"]
}
