import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, step}
import dream_test/gherkin/world.{delete, has, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner

fn step_store(context: StepContext) {
  put(context.world, "temp", True)
  Ok(succeed())
}

fn step_delete(context: StepContext) {
  delete(context.world, "temp")
  Ok(succeed())
}

fn step_is_absent(context: StepContext) {
  has(context.world, "temp")
  |> should
  |> be_equal(False)
  |> or_fail_with("expected temp to be absent")
}

pub fn register(registry) {
  registry
  |> step("temp is stored", step_store)
  |> step("temp is deleted", step_delete)
  |> step("temp should be absent", step_is_absent)
}

pub fn tests() {
  let steps = steps.new() |> register()

  feature("World: has + delete", steps, [
    scenario("Deleting a key", [
      given("temp is stored"),
      when("temp is deleted"),
      then("temp should be absent"),
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
