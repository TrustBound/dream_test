//// Gherkin failures for the failure showcase example.

import dream_test/gherkin/discover
import dream_test/gherkin/steps.{type StepContext}
import dream_test/matchers.{be_equal, or_fail_with, should}

fn step_counter_at_zero(_count: Int, _context: StepContext) {
  Ok(0)
}

fn step_increment_counter(count: Int, _context: StepContext) {
  Ok(count + 1)
}

fn step_counter_should_be_two(count: Int, _context: StepContext) {
  count
  |> should
  |> be_equal(2)
  |> or_fail_with("intentional gherkin failure: expected counter to be 2")
}

fn step_counter_should_be_one(count: Int, _context: StepContext) {
  count
  |> should
  |> be_equal(1)
  |> or_fail_with("expected counter to be 1")
}

pub fn tests() {
  let registry =
    steps.new(initial: 0)
    |> steps.given("a counter at 0", step_counter_at_zero)
    |> steps.when("I increment the counter", step_increment_counter)
    |> steps.then("the counter should be 2", step_counter_should_be_two)
    |> steps.then("the counter should be 1", step_counter_should_be_one)

  discover.features("features/*.feature")
  |> discover.with_registry(registry)
  |> discover.to_suite("Failure Showcase (gherkin)")
}
