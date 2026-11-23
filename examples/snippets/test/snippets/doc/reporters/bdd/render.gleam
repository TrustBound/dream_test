import dream_test/reporters/bdd
import dream_test/reporters/types as reporter_types
import dream_test/types.{Passed, TestResult, Unit}

pub fn summary_of_one_passed_test() -> String {
  let report =
    types.run_report(
      tests: [
        TestResult(
          name: "starts empty",
          groups: ["Cart"],
          status: Passed,
          duration_ms: 3,
          tags: [],
          failures: [],
          kind: Unit,
        ),
      ],
      hook_failures: [],
      reporter_crashes: [],
    )
  bdd.render(
    config: reporter_types.BddReporterConfig(
      color: False,
      mode: reporter_types.BddSummaryOnly,
    ),
    report: report,
  )
}
