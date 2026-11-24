import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, get_int}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import gleam/result

fn step_have_items(_count: Int, context: StepContext) -> Result(Int, String) {
  get_int(context.captures, 0)
}

fn step_add_items(count: Int, context: StepContext) -> Result(Int, String) {
  use added <- result.try(get_int(context.captures, 0))
  Ok(count + added)
}

fn step_should_have(
  count: Int,
  context: StepContext,
) -> Result(AssertionResult, String) {
  use expected <- result.try(get_int(context.captures, 0))
  count
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn cart_feature_suite() -> TestSuite {
  let assert Ok(feature) =
    parser.parse_file("test/features/shopping_cart.feature")

  let registry =
    steps.new(initial: 0)
    |> steps.given("I have {int} items in my cart", step_have_items)
    |> steps.when("I add {int} more items", step_add_items)
    |> steps.then("I should have {int} items total", step_should_have)

  steps.feature_suite(registry: registry, feature: feature)
}
