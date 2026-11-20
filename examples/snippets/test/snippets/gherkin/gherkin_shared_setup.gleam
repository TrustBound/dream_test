import dream_test/gherkin/parser
import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, SuiteFeature, SuiteGroup,
}
import dream_test/gherkin/types
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit
import gleam/result

const cart_text =
  "Feature: Cart
  Scenario: The shop is open
    Then the shop has 3 items
"

const stock_text =
  "Feature: Stock
  Scenario: The stock is full
    Then the shop has 3 items
"

fn open_shop() -> Result(Int, String) {
  Ok(3)
}

fn close_shop(_items: Int) -> Result(Nil, String) {
  Ok(Nil)
}

fn has_items(items: Int, context: StepContext) {
  use expected <- result.try(steps.get_int(context.captures, 0))
  items
  |> should
  |> be_equal(expected)
  |> or_fail_with("the shop should have the items")
}

fn shop_steps() -> StepRegistry(Int) {
  steps.new_with_setup(setup: open_shop, teardown: close_shop)
  |> steps.then("the shop has {int} items", has_items)
}

/// Two Features in one suite: the setup runs one time for both.
fn shop_suite(cart: types.Feature, stock: types.Feature) -> TestSuite {
  steps.to_suite(registry: shop_steps(), name: "Shop", tags: [], children: [
    SuiteFeature(cart),
    SuiteGroup(name: "Warehouse", tags: ["warehouse"], children: [
      SuiteFeature(stock),
    ]),
  ])
}

pub fn tests() -> TestSuite {
  case parser.parse_string(cart_text), parser.parse_string(stock_text) {
    Ok(cart), Ok(stock) -> shop_suite(cart, stock)
    _, _ -> unit.describe("Shop", [unit.it("parses", parse_failed)])
  }
}

fn parse_failed() {
  Error("a feature text did not parse")
}
