//// README: Gherkin hero example (featured at top)

import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, get_int, new_registry, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/reporter/bdd.{report}
import dream_test/runner.{run_suite}
import dream_test/types.{type AssertionResult, AssertionOk}
import gleam/io
import gleam/result

fn step_have_items(context: StepContext) -> AssertionResult {
  let count = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "cart", count)
  AssertionOk
}

fn step_add_items(context: StepContext) -> AssertionResult {
  let current = get_or(context.world, "cart", 0)
  let to_add = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "cart", current + to_add)
  AssertionOk
}

fn step_should_have(context: StepContext) -> AssertionResult {
  let expected = get_int(context.captures, 0) |> result.unwrap(0)
  get_or(context.world, "cart", 0)
  |> should()
  |> equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  let steps =
    new_registry()
    |> step("I have {int} items in my cart", step_have_items)
    |> step("I add {int} more items", step_add_items)
    |> step("I should have {int} items total", step_should_have)

  feature("Shopping Cart", steps, [
    scenario("Adding items to cart", [
      given("I have 3 items in my cart"),
      when("I add 2 more items"),
      then("I should have 5 items total"),
    ]),
  ])
}

pub fn main() {
  tests()
  |> run_suite()
  |> report(io.print)
}
