import dream_test/gherkin/feature.{
  and, background, feature_with_background, given, scenario, then, when,
  with_tags,
}
import dream_test/gherkin/steps.{type StepContext, get_int, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/int
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
  let actual = get_or(context.world, "cart", 0)
  actual
  |> should
  |> be_equal(expected)
  |> or_fail_with("Expected " <> int.to_string(expected) <> " items")
}

pub fn tests() {
  let steps =
    steps.new()
    |> step("the server is running", step_server_running)
    |> step("the cart is empty", step_empty_cart)
    |> step("I add {int} items", step_add_items)
    |> step("the cart should have {int} items", step_verify_count)

  let bg = background([given("the server is running")])

  feature_with_background("Shopping Cart", steps, bg, [
    scenario("Adding items", [
      given("the cart is empty"),
      when("I add 3 items"),
      then("the cart should have 3 items"),
    ])
      |> with_tags(["smoke"]),
    scenario("Adding more items", [
      given("the cart is empty"),
      when("I add 2 items"),
      and("I add 3 items"),
      then("the cart should have 5 items"),
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
