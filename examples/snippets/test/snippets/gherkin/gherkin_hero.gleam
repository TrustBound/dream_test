import dream_test/gherkin/feature.{but, feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, get_int, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/result

fn step_have_items(context: StepContext) {
  let count = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "cart", count)
  Ok(succeed())
}

fn step_add_items(context: StepContext) {
  let current = get_or(context.world, "cart", 0)
  let to_add = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "cart", current + to_add)
  Ok(succeed())
}

fn step_should_have(context: StepContext) {
  let expected = get_int(context.captures, 0) |> result.unwrap(0)
  get_or(context.world, "cart", 0)
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  let steps =
    steps.new()
    |> step("I have {int} items in my cart", step_have_items)
    |> step("I add {int} more items", step_add_items)
    |> step("I should have {int} items total", step_should_have)

  feature("Shopping Cart", steps, [
    scenario("Adding items to cart", [
      given("I have 3 items in my cart"),
      when("I add 2 more items"),
      then("I should have 5 items total"),
      but("I should have 5 items total"),
    ]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
