import dream_test/matchers.{match_snapshot, or_fail_with, should}
import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/types
import dream_test/unit.{describe, it}

fn sample_results() -> List(types.TestResult) {
  [
    types.TestResult(
      name: "Scenario A",
      full_name: ["Example Feature", "Scenario A"],
      status: types.Passed,
      duration_ms: 0,
      tags: [],
      failures: [],
      kind: types.GherkinScenario("example"),
    ),
  ]
}

pub fn tests() {
  describe("Gherkin formatting", [
    it("format returns a report string", fn() {
      gherkin_reporter.format(sample_results())
      |> should
      |> match_snapshot("./test/snapshots/gherkin_format_report.snap")
      |> or_fail_with("expected formatted report snapshot match")
    }),
  ])
}
