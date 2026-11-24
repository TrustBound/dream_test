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

pub fn new_path_is_the_describe_path() -> Result(AssertionResult, String) {
  let bdd.FormatIncrementalResult(text: _text, new_path: new_path) =
    bdd.format_incremental(passing_result(), [])

  new_path
  |> should
  |> be_equal(["Example Suite"])
  |> or_fail_with("expected new_path to be the describe path")
}
