import dream_test/gherkin/discover
import dream_test/gherkin/steps.{type StepContext, get_int}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import gleam/result

pub type Cart {
  Cart(server_running: Bool, items: Int)
}

fn step_server_running(
  cart: Cart,
  _context: StepContext,
) -> Result(Cart, String) {
  Ok(Cart(..cart, server_running: True))
}

fn step_empty_cart(cart: Cart, _context: StepContext) -> Result(Cart, String) {
  Ok(Cart(..cart, items: 0))
}

fn step_add_items(cart: Cart, context: StepContext) -> Result(Cart, String) {
  use added <- result.try(get_int(context.captures, 0))
  Ok(Cart(..cart, items: cart.items + added))
}

fn step_verify_count(
  cart: Cart,
  context: StepContext,
) -> Result(AssertionResult, String) {
  use expected <- result.try(get_int(context.captures, 0))
  cart.items
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn cart_features() -> TestSuite {
  // Define the steps and the state each scenario starts from
  let steps =
    steps.new(initial: Cart(server_running: False, items: 0))
    |> steps.given("the server is running", step_server_running)
    |> steps.given("the cart is empty", step_empty_cart)
    |> steps.when("I add {int} items", step_add_items)
    |> steps.then("the cart should have {int} items", step_verify_count)

  // Discover and load all .feature files
  discover.features("test/*.feature")
  |> discover.with_registry(steps)
  |> discover.to_suite("cart_features")
}
