import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/types.{
  type AssertionResult, type TestResult, Passed, TestResult, Unit,
}
import gleam/erlang/process
import gleam/result

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

pub fn report_writes_the_text() -> Result(AssertionResult, String) {
  let subject = process.new_subject()
  let _report =
    bdd.report(
      types.run_report(
        tests: [passing_result()],
        hook_failures: [],
        reporter_crashes: [],
      ),
      process.send(subject, _),
    )

  use text <- result.try(
    process.receive(subject, within: 100)
    |> result.replace_error("expected the report to write its text"),
  )

  text
  |> should
  |> be_equal(
    "Example Suite\n  ✓ passes\n\nSummary: 1 run, 0 failed, 1 passed in 0ms\n",
  )
  |> or_fail_with("expected the written report")
}
