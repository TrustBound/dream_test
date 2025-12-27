import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/types
import dream_test/unit.{describe, it}

fn gherkin_result() -> types.TestResult {
  types.TestResult(
    name: "Scenario A",
    full_name: ["Example Feature", "Scenario A"],
    status: types.Passed,
    duration_ms: 0,
    tags: [],
    failures: [],
    kind: types.GherkinScenario("example"),
  )
}

fn unit_result() -> types.TestResult {
  types.TestResult(
    name: "passes",
    full_name: ["Example Suite", "passes"],
    status: types.Passed,
    duration_ms: 0,
    tags: [],
    failures: [],
    kind: types.Unit,
  )
}

pub fn tests() {
  describe("Gherkin reporter: is_gherkin_result", [
    it("returns True for GherkinScenario results", fn() {
      gherkin_reporter.is_gherkin_result(gherkin_result())
      |> should
      |> be_equal(True)
      |> or_fail_with("expected True for gherkin results")
    }),
    it("returns False for non-gherkin results", fn() {
      gherkin_reporter.is_gherkin_result(unit_result())
      |> should
      |> be_equal(False)
      |> or_fail_with("expected False for unit results")
    }),
  ])
}
