import dream_test/matchers.{match_snapshot, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/types
import dream_test/unit.{describe, it}

fn sample_results() -> List(types.TestResult) {
  [
    types.TestResult(
      name: "passes",
      full_name: ["Example Suite", "passes"],
      status: types.Passed,
      duration_ms: 0,
      tags: [],
      failures: [],
      kind: types.Unit,
    ),
  ]
}

pub fn tests() {
  describe("BDD formatting", [
    it("format returns a report string", fn() {
      let report = bdd.format(sample_results())

      report
      |> should
      |> match_snapshot("./test/snapshots/bdd_format_report.snap")
      |> or_fail_with("expected formatted report snapshot match")
    }),
  ])
}
