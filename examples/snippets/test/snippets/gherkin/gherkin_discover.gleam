//// README: Gherkin feature discovery example

import dream_test/gherkin/discover
import dream_test/gherkin/steps.{type StepContext, get_int, new_registry, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters
import dream_test/runner
import gleam/io
import gleam/result

fn step_server_running(context: StepContext) {
  put(context.world, "server_running", True)
  Ok(succeed())
}

fn step_empty_cart(context: StepContext) {
  put(context.world, "cart", 0)
  Ok(succeed())
}

fn step_add_items(context: StepContext) {
  let current = get_or(context.world, "cart", 0)
  let to_add = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "cart", current + to_add)
  Ok(succeed())
}

fn step_verify_count(context: StepContext) {
  let expected = get_int(context.captures, 0) |> result.unwrap(0)
  get_or(context.world, "cart", 0)
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  // Define step handlers
  let steps =
    new_registry()
    |> step("the server is running", step_server_running)
    |> step("the cart is empty", step_empty_cart)
    |> step("I add {int} items", step_add_items)
    |> step("the cart should have {int} items", step_verify_count)

  // Discover and load all .feature files
  discover.features("test/*.feature")
  |> discover.with_registry(steps)
  |> discover.to_suite("cart_features")
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
