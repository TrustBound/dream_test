import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, feature_suite, get_int}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/result

pub type Cart {
  Cart(server_running: Bool, items: Int)
}

fn step_server_running(cart: Cart, _context: StepContext) {
  Ok(Cart(..cart, server_running: True))
}

fn step_empty_cart(cart: Cart, _context: StepContext) {
  Ok(Cart(..cart, items: 0))
}

fn step_add_items(cart: Cart, context: StepContext) {
  use to_add <- result.try(get_int(context.captures, 0))
  Ok(Cart(..cart, items: cart.items + to_add))
}

fn step_verify_count(cart: Cart, context: StepContext) {
  use expected <- result.try(get_int(context.captures, 0))
  cart.items
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  // Define the steps and the state each scenario starts from
  let steps =
    steps.new(initial: Cart(server_running: False, items: 0))
    |> steps.given("the server is running", step_server_running)
    |> steps.given("the cart is empty", step_empty_cart)
    |> steps.when("I add {int} items", step_add_items)
    |> steps.then("the cart should have {int} items", step_verify_count)

  // Parse the .feature file
  let assert Ok(feature) = parser.parse_file("test/cart.feature")

  // Make a suite from the Feature
  feature_suite(registry: steps, feature: feature)
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
