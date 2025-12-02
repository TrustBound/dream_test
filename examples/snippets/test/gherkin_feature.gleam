//// README: Gherkin feature definition example

import dream_test/assertions/should.{fail_with}
import dream_test/gherkin/feature.{
  and, background, feature_with_background, given, scenario, then, when,
  with_tags,
}
import dream_test/gherkin/steps.{type StepContext, get_int, new_registry, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/reporter/bdd.{report}
import dream_test/runner.{run_suite}
import dream_test/types.{type AssertionResult, AssertionOk}
import gleam/int
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
  let actual = get_or(context.world, "cart", 0)
  case actual == expected {
    True -> AssertionOk
    False -> fail_with("Expected " <> int.to_string(expected) <> " items")
  }
}

pub fn tests() {
  let steps =
    new_registry()
    |> step("I have an empty cart", step_empty_cart)
    |> step("I add {int} items", step_add_items)
    |> step("I should have {int} items", step_verify_count)

  let bg = background([given("I have an empty cart")])

  feature_with_background("Shopping Cart", steps, bg, [
    scenario("Adding items", [
      when("I add 3 items"),
      then("I should have 3 items"),
    ])
      |> with_tags(["smoke"]),
    scenario("Adding more items", [
      when("I add 2 items"),
      and("I add 3 items"),
      then("I should have 5 items"),
    ]),
  ])
}

pub fn main() {
  tests()
  |> run_suite()
  |> report(io.print)
}
