import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, feature_suite, get_int}
import dream_test/matchers.{be_equal, or_fail_with, should}
import gleam/result

pub type Shop {
  Shop(open: Bool, stock: Int)
}

fn step_shop_open(shop: Shop, _context: StepContext) {
  Ok(Shop(..shop, open: True))
}

fn step_set_stock(shop: Shop, context: StepContext) {
  use count <- result.try(get_int(context.captures, 0))
  Ok(Shop(..shop, stock: count))
}

fn step_sell(shop: Shop, context: StepContext) {
  use sold <- result.try(get_int(context.captures, 0))
  Ok(Shop(..shop, stock: shop.stock - sold))
}

fn step_check_stock(shop: Shop, context: StepContext) {
  use expected <- result.try(get_int(context.captures, 0))
  shop.stock
  |> should
  |> be_equal(expected)
  |> or_fail_with("Stock count mismatch")
}

pub fn tests() {
  let steps =
    steps.new(initial: Shop(open: False, stock: 0))
    |> steps.given("the shop is open", step_shop_open)
    |> steps.given("the stock holds {int} items", step_set_stock)
    |> steps.when("I sell {int} items", step_sell)
    |> steps.then("the stock holds {int} items", step_check_stock)

  // Each Rule becomes a group named "Rule: <name>".
  // Each Examples row becomes one test, for example
  // "Sell different amounts (Small orders, Example 1)".
  let assert Ok(feature) = parser.parse_file("test/features/stock.feature")
  feature_suite(registry: steps, feature: feature)
}
