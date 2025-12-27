//// Gherkin failures for the failure showcase example.

import dream_test/gherkin/discover
import dream_test/gherkin/steps.{type StepContext, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}

fn step_counter_at_zero(context: StepContext) {
  put(context.world, "count", 0)
  Ok(succeed())
}

fn step_increment_counter(context: StepContext) {
  let current = get_or(context.world, "count", 0)
  put(context.world, "count", current + 1)
  Ok(succeed())
}

fn step_counter_should_be_two(context: StepContext) {
  get_or(context.world, "count", 0)
  |> should
  |> be_equal(2)
  |> or_fail_with("intentional gherkin failure: expected counter to be 2")
}

fn step_counter_should_be_one(context: StepContext) {
  get_or(context.world, "count", 0)
  |> should
  |> be_equal(1)
  |> or_fail_with("expected counter to be 1")
}

pub fn tests() {
  let registry =
    steps.new()
    |> step("a counter at 0", step_counter_at_zero)
    |> step("I increment the counter", step_increment_counter)
    |> step("the counter should be 2", step_counter_should_be_two)
    |> step("the counter should be 1", step_counter_should_be_one)

  discover.features("features/*.feature")
  |> discover.with_registry(registry)
  |> discover.to_suite("Failure Showcase (gherkin)")
}
