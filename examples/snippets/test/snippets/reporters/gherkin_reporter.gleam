import dream_test/gherkin/feature.{feature, given, scenario, then}
import dream_test/gherkin/steps
import dream_test/matchers.{succeed}
import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/runner
import dream_test/types.{type RunReport}
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
  let report = runner.new([tests()]) |> runner.run()
  gherkin_reporter.report(report, io.print)
  halt(exit_status(report))
}

/// 1 when a test or a hook failed, else 0.
fn exit_status(report: RunReport) -> Int {
  case types.failed(report) {
    True -> 1
    False -> 0
  }
}

/// End the program with an exit status. It never returns.
@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
