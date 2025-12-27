import dream_test/gherkin/feature.{feature, given, scenario, then}
import dream_test/gherkin/steps.{type StepContext, step}
import dream_test/gherkin/world.{get, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner

fn step_store(context: StepContext) {
  put(context.world, "count", 42)
  Ok(succeed())
}

fn step_count_is_42(context: StepContext) {
  case get(context.world, "count") {
    Ok(count) ->
      count
      |> should
      |> be_equal(42)
      |> or_fail_with("count mismatch")
    Error(message) -> Error(message)
  }
}

pub fn register(registry) {
  registry
  |> step("count is stored", step_store)
  |> step("count should be 42", step_count_is_42)
}

pub fn tests() {
  let steps = steps.new() |> register()

  feature("World: get", steps, [
    scenario("Reading a stored value", [
      given("count is stored"),
      then("count should be 42"),
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
