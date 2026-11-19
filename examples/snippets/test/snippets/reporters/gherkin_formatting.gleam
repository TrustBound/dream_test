import dream_test/matchers.{match_snapshot, or_fail_with, should}
import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/option.{None}

fn sample_results() -> List(types.TestResult) {
  [
    types.TestResult(
      name: "Scenario A",
      groups: ["Example Feature"],
      status: types.Passed,
      duration_ms: 0,
      tags: [],
      failures: [],
      kind: types.GherkinScenario(scenario_id: "example", rule: None),
    ),
  ]
}

pub fn tests() {
  describe("Gherkin formatting", [
    it("format returns a report string", fn() {
      gherkin_reporter.format(
        types.run_report(
          tests: sample_results(),
          teardown_failures: [],
          reporter_crashes: [],
        ),
      )
      |> should
      |> match_snapshot("./test/snapshots/gherkin_format_report.snap")
      |> or_fail_with("expected formatted report snapshot match")
    }),
  ])
}
