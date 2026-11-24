import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/types.{
  type AssertionResult, type TestResult, Passed, TestResult, Unit,
}

pub fn passing_result() -> TestResult {
  TestResult(
    name: "passes",
    groups: ["Example Suite"],
    status: Passed,
    duration_ms: 0,
    tags: [],
    failures: [],
    kind: Unit,
  )
}

pub fn summary_counts_the_passing_test() -> Result(AssertionResult, String) {
  let summary =
    bdd.format_summary_only(
      types.run_report(
        tests: [passing_result()],
        hook_failures: [],
        reporter_crashes: [],
      ),
    )

  summary
  |> should
  |> be_equal("Summary: 1 run, 0 failed, 1 passed in 0ms\n")
  |> or_fail_with("expected the summary line")
}
