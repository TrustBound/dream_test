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

pub fn parts_hold_the_header_and_the_test_line() -> Result(
  AssertionResult,
  String,
) {
  let result = passing_result()
  let bdd.FormatIncrementalPartsResult(
    headers: headers,
    test_line: test_line,
    new_path: _new_path,
  ) = bdd.format_incremental_parts_with_test_indent(result, [], 0)

  #(headers, test_line)
  |> should
  |> be_equal(#("Example Suite\n", "  ✓ passes\n"))
  |> or_fail_with("expected the incremental parts")
}
