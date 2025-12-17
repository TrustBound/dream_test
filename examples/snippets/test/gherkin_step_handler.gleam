//// README: Gherkin step handler example

import dream_test/assertions/should.{equal, or_fail_with, should, succeed}
import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, get_float, new_registry, step,
}
import dream_test/gherkin/world.{get_or, put}
import dream_test/reporter/api as reporter
import dream_test/runner
import dream_test/types.{type AssertionResult}
import gleam/io
import gleam/result

// Each step handler receives a StepContext
fn step_have_balance(context: StepContext) -> Result(AssertionResult, String) {
  // {float} captures the numeric value (even with $ prefix)
  let balance = get_float(context.captures, 0) |> result.unwrap(0.0)
  put(context.world, "balance", balance)
  Ok(succeed())
}

fn step_withdraw(context: StepContext) -> Result(AssertionResult, String) {
  let current = get_or(context.world, "balance", 0.0)
  let amount = get_float(context.captures, 0) |> result.unwrap(0.0)
  put(context.world, "balance", current -. amount)
  Ok(succeed())
}

fn step_balance_is(context: StepContext) -> Result(AssertionResult, String) {
  let expected = get_float(context.captures, 0) |> result.unwrap(0.0)
  get_or(context.world, "balance", 0.0)
  |> should()
  |> equal(expected)
  |> or_fail_with("Balance mismatch")
}

pub fn register(registry: StepRegistry) -> StepRegistry {
  registry
  |> step("I have a balance of ${float}", step_have_balance)
  |> step("I withdraw ${float}", step_withdraw)
  |> step("my balance should be ${float}", step_balance_is)
}

pub fn tests() {
  let steps = new_registry() |> register()

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
  |> runner.reporter(reporter.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
