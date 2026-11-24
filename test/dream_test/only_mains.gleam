//// Test mains for test/dream_test/only_test.gleam.
////
//// The tests call them in a new `erl` process with plain arguments, the
//// same as `gleam test -- --only "<path>"`, so they check that the runner
//// reads the real command line.

import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/types.{type RunReport, type TestResult, AssertionOk}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/string

fn forecast_tests() {
  describe("Forecast", [
    it("gives the forecast for Bergen", fn() { Ok(AssertionOk) }),
    it("gives the forecast for Oslo", fn() { Error("Oslo has no forecast") }),
  ])
}

/// Each test that ran, one per line.
fn names_of_tests(report: RunReport) -> String {
  report
  |> types.report_tests
  |> list.map(result_line)
  |> string.concat
}

fn result_line(result: TestResult) -> String {
  "ran: "
  <> string.join(types.full_name(result.groups, result.name), "/")
  <> "\n"
}

/// The Forecast suite: the Bergen test passes and the Oslo test fails.
pub fn forecast_run() -> Nil {
  let _ =
    runner.new([forecast_tests()])
    |> runner.results_reporters([reporter_types.Custom(names_of_tests)])
    |> runner.exit_on_failure()
    |> runner.run()
  Nil
}
