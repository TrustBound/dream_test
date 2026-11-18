import dream_test/gherkin/feature.{feature, given, scenario, then}
import dream_test/gherkin/steps.{
  type StepContext, get_float, get_int, get_string, get_word,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/result

pub type Values {
  Values(int: Int, float: Float, string: String, word: String)
}

// {int} captures integers
fn step_int(values: Values, context: StepContext) {
  use value <- result.try(get_int(context.captures, 0))
  Ok(Values(..values, int: value))
}

// {float} captures decimals (works with $ prefix too)
fn step_float(values: Values, context: StepContext) {
  use value <- result.try(get_float(context.captures, 0))
  Ok(Values(..values, float: value))
}

// {string} captures quoted strings
fn step_string(values: Values, context: StepContext) {
  use value <- result.try(get_string(context.captures, 0))
  Ok(Values(..values, string: value))
}

// {word} captures a single unquoted word
fn step_word(values: Values, context: StepContext) {
  use value <- result.try(get_word(context.captures, 0))
  Ok(Values(..values, word: value))
}

fn step_everything_works(values: Values, _context: StepContext) {
  values
  |> should
  |> be_equal(Values(
    int: 42,
    float: 19.99,
    string: "hello world",
    word: "alice",
  ))
  |> or_fail_with("every placeholder should give its value")
}

pub fn tests() {
  let steps =
    steps.new(initial: Values(int: 0, float: 0.0, string: "", word: ""))
    |> steps.given("I have {int} items", step_int)
    |> steps.given("the price is ${float}", step_float)
    |> steps.given("the message is {string}", step_string)
    |> steps.given("the user is {word}", step_word)
    |> steps.then("everything works", step_everything_works)

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
