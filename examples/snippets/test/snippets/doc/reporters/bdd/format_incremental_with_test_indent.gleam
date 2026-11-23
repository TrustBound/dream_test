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

pub fn first_result_prints_its_group() -> Result(AssertionResult, String) {
  let result = passing_result()
  let bdd.FormatIncrementalResult(text: text, new_path: _new_path) =
    bdd.format_incremental_with_test_indent(result, [], 0)

  text
  |> should
  |> be_equal("Example Suite\n  ✓ passes\n")
  |> or_fail_with("expected the incremental output")
}
