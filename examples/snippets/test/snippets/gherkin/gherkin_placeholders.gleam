import dream_test/gherkin/feature.{feature, given, scenario, then}
import dream_test/gherkin/steps.{
  type StepContext, get_float, get_int, get_string, get_word, step,
}
import dream_test/gherkin/world.{put}
import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/result

// {int} captures integers
fn step_int(context: StepContext) {
  let value = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "int", value)
  Ok(succeed())
}

// {float} captures decimals (works with $ prefix too)
fn step_float(context: StepContext) {
  let value = get_float(context.captures, 0) |> result.unwrap(0.0)
  put(context.world, "float", value)
  Ok(succeed())
}

// {string} captures quoted strings
fn step_string(context: StepContext) {
  let value = get_string(context.captures, 0) |> result.unwrap("")
  put(context.world, "string", value)
  Ok(succeed())
}

// {word} captures a single unquoted word
fn step_word(context: StepContext) {
  let value = get_word(context.captures, 0) |> result.unwrap("")
  put(context.world, "word", value)
  Ok(succeed())
}

fn step_pass(_context) {
  Ok(succeed())
}

pub fn tests() {
  let steps =
    steps.new()
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
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
