import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, get_int}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import gleam/result

fn step_have_items(context: StepContext) {
  put(context.world, "cart", get_int(context.captures, 0) |> result.unwrap(0))
  Ok(succeed())
}

fn step_add_items(context: StepContext) {
  let current = get_or(context.world, "cart", 0)
  put(
    context.world,
    "cart",
    current + { get_int(context.captures, 0) |> result.unwrap(0) },
  )
  Ok(succeed())
}

fn step_verify_count(context: StepContext) {
  get_or(context.world, "cart", 0)
  |> should
  |> be_equal(get_int(context.captures, 0) |> result.unwrap(0))
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  let steps =
    steps.new()
    |> steps.given("I have {int} items in my cart", step_have_items)
    |> steps.when_("I add {int} more items", step_add_items)
    |> steps.then_("I should have {int} items total", step_verify_count)

  let assert Ok(feature) =
    parser.parse_file("test/features/shopping_cart.feature")
  to_test_suite(FeatureConfig(feature: feature, step_registry: steps))
}
