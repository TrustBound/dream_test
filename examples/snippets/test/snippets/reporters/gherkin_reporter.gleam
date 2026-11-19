import dream_test/gherkin/feature.{feature, given, scenario, then}
import dream_test/gherkin/steps
import dream_test/matchers.{succeed}
import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/runner
import gleam/io

fn step_ok(state: Nil, _context: steps.StepContext) {
  Ok(state)
}

fn check_ok(_state: Nil, _context: steps.StepContext) {
  Ok(succeed())
}

pub fn tests() {
  let steps =
    steps.new(initial: Nil)
    |> steps.given("everything is fine", step_ok)
    |> steps.then("everything is fine", check_ok)

  feature("Gherkin Reporting", steps, [
    scenario("A passing scenario", [
      given("everything is fine"),
      then("everything is fine"),
    ]),
  ])
}

pub fn main() {
  let results = runner.new([tests()]) |> runner.run()
  gherkin_reporter.report(results, io.print)
}
