import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, get_int}
import dream_test/matchers.{be_equal, or_fail_with, should}
import gleam/result

fn step_have_items(_cart: Int, context: StepContext) {
  get_int(context.captures, 0)
}

fn step_add_items(cart: Int, context: StepContext) {
  use added <- result.try(get_int(context.captures, 0))
  Ok(cart + added)
}

fn step_verify_count(cart: Int, context: StepContext) {
  use expected <- result.try(get_int(context.captures, 0))
  cart
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  let steps =
    steps.new(initial: 0)
    |> steps.given("I have {int} items in my cart", step_have_items)
    |> steps.when("I add {int} more items", step_add_items)
    |> steps.then("I should have {int} items total", step_verify_count)

  let assert Ok(feature) =
    parser.parse_file("test/features/shopping_cart.feature")
  to_test_suite(FeatureConfig(feature: feature, step_registry: steps))
}
