//// README: Gherkin placeholder types example

import dream_test/gherkin/feature.{feature, given, scenario, then}
import dream_test/gherkin/steps.{
  type StepContext, get_float, get_int, get_string, get_word, new_registry, step,
}
import dream_test/gherkin/world.{put}
import dream_test/reporter/bdd.{report}
import dream_test/runner.{run_suite}
import dream_test/types.{type AssertionResult, AssertionOk}
import gleam/io
import gleam/result

// {int} captures integers
fn step_int(context: StepContext) -> AssertionResult {
  let value = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "int", value)
  AssertionOk
}

// {float} captures decimals (works with $ prefix too)
fn step_float(context: StepContext) -> AssertionResult {
  let value = get_float(context.captures, 0) |> result.unwrap(0.0)
  put(context.world, "float", value)
  AssertionOk
}

// {string} captures quoted strings
fn step_string(context: StepContext) -> AssertionResult {
  let value = get_string(context.captures, 0) |> result.unwrap("")
  put(context.world, "string", value)
  AssertionOk
}

// {word} captures a single unquoted word
fn step_word(context: StepContext) -> AssertionResult {
  let value = get_word(context.captures, 0) |> result.unwrap("")
  put(context.world, "word", value)
  AssertionOk
}

fn step_pass(_context: StepContext) -> AssertionResult {
  AssertionOk
}

pub fn tests() {
  let steps =
    new_registry()
    |> step("I have {int} items", step_int)
    |> step("the price is ${float}", step_float)
    |> step("the message is {string}", step_string)
    |> step("the user is {word}", step_word)
    |> step("everything works", step_pass)

  feature("Placeholder Types", steps, [
    scenario("Using different placeholders", [
      given("I have 42 items"),
      given("the price is $19.99"),
      given("the message is \"hello world\""),
      given("the user is alice"),
      then("everything works"),
    ]),
  ])
}

pub fn main() {
  tests()
  |> run_suite()
  |> report(io.print)
}
