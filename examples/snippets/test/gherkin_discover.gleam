//// README: Gherkin feature discovery example

import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/gherkin/discover
import dream_test/gherkin/steps.{type StepContext, get_int, new_registry, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/reporter/gherkin.{report}
import dream_test/runner.{run_suite}
import dream_test/types.{type AssertionResult, AssertionOk}
import gleam/io
import gleam/result

fn step_empty_cart(context: StepContext) -> AssertionResult {
  put(context.world, "cart", 0)
  AssertionOk
}

fn step_add_items(context: StepContext) -> AssertionResult {
  let current = get_or(context.world, "cart", 0)
  let to_add = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "cart", current + to_add)
  AssertionOk
}

fn step_verify_count(context: StepContext) -> AssertionResult {
  let expected = get_int(context.captures, 0) |> result.unwrap(0)
  get_or(context.world, "cart", 0)
  |> should()
  |> equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  // Define step handlers
  let steps =
    new_registry()
    |> step("I have an empty cart", step_empty_cart)
    |> step("I add {int} items", step_add_items)
    |> step("the cart should have {int} items", step_verify_count)

  // Discover and load all .feature files
  discover.features("test/*.feature")
  |> discover.with_registry(steps)
  |> discover.to_suite("cart_features")
}

pub fn main() {
  tests()
  |> run_suite()
  |> report(io.print)
}
