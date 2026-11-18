import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, get_float}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/result

// The scenario state is the balance. A Given or When step returns the new balance.
fn step_have_balance(_balance: Float, context: StepContext) {
  // {float} captures the numeric value (even with $ prefix)
  get_float(context.captures, 0)
}

fn step_withdraw(balance: Float, context: StepContext) {
  use amount <- result.try(get_float(context.captures, 0))
  Ok(balance -. amount)
}

// A Then step gets the balance and returns an assertion result.
fn step_balance_is(balance: Float, context: StepContext) {
  use expected <- result.try(get_float(context.captures, 0))
  balance
  |> should
  |> be_equal(expected)
  |> or_fail_with("Balance mismatch")
}

pub fn register(registry) {
  registry
  |> steps.given("I have a balance of ${float}", step_have_balance)
  |> steps.when("I withdraw ${float}", step_withdraw)
  |> steps.then("my balance should be ${float}", step_balance_is)
}

pub fn tests() {
  let steps = steps.new(initial: 0.0) |> register()

  feature("Bank Account", steps, [
    scenario("Withdrawal", [
      given("I have a balance of $100.00"),
      when("I withdraw $30.00"),
      then("my balance should be $70.00"),
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
