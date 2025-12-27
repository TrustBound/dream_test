import dream_test/gherkin/feature.{feature, given, scenario, then}
import dream_test/gherkin/steps.{step}
import dream_test/matchers.{succeed}
import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/runner
import gleam/io

fn step_ok(_context) {
  Ok(succeed())
}

pub fn tests() {
  let steps = steps.new() |> step("everything is fine", step_ok)

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
