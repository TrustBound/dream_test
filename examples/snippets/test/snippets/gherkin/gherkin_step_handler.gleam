import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, get_float, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/result

// NOTE: We annotate `StepContext` because record field access needs a known type.
fn step_have_balance(context: StepContext) {
  // {float} captures the numeric value (even with $ prefix)
  let balance = get_float(context.captures, 0) |> result.unwrap(0.0)
  put(context.world, "balance", balance)
  Ok(succeed())
}

fn step_withdraw(context: StepContext) {
  let current = get_or(context.world, "balance", 0.0)
  let amount = get_float(context.captures, 0) |> result.unwrap(0.0)
  put(context.world, "balance", current -. amount)
  Ok(succeed())
}

fn step_balance_is(context: StepContext) {
  let expected = get_float(context.captures, 0) |> result.unwrap(0.0)
  get_or(context.world, "balance", 0.0)
  |> should
  |> be_equal(expected)
  |> or_fail_with("Balance mismatch")
}

pub fn register(registry) {
  registry
  |> step("I have a balance of ${float}", step_have_balance)
  |> step("I withdraw ${float}", step_withdraw)
  |> step("my balance should be ${float}", step_balance_is)
}

pub fn tests() {
  let steps = steps.new() |> register()

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
