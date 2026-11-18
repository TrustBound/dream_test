import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, get_int}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import gleam/result

fn step_shop_open(context: StepContext) {
  put(context.world, "open", True)
  Ok(succeed())
}

fn step_set_stock(context: StepContext) {
  let count = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "stock", count)
  Ok(succeed())
}

fn step_sell(context: StepContext) {
  let stock = get_or(context.world, "stock", 0)
  let sold = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "stock", stock - sold)
  Ok(succeed())
}

fn step_check_stock(context: StepContext) {
  let expected = get_int(context.captures, 0) |> result.unwrap(0)
  get_or(context.world, "stock", 0)
  |> should
  |> be_equal(expected)
  |> or_fail_with("Stock count mismatch")
}

pub fn tests() {
  let steps =
    steps.new()
    |> steps.given("the shop is open", step_shop_open)
    |> steps.given("the stock holds {int} items", step_set_stock)
    |> steps.when_("I sell {int} items", step_sell)
    |> steps.then_("the stock holds {int} items", step_check_stock)

  // Each Rule becomes a group named "Rule: <name>".
  // Each Examples row becomes one test, for example
  // "Sell different amounts (Small orders, Example 1)".
  let assert Ok(feature) = parser.parse_file("test/features/stock.feature")
  to_test_suite(FeatureConfig(feature: feature, step_registry: steps))
}
