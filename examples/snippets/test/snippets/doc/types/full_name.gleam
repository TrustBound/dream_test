import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn groups_then_test_name() -> Result(AssertionResult, String) {
  types.full_name(["Cart", "totals"], "adds tax")
  |> should
  |> be_equal(["Cart", "totals", "adds tax"])
  |> or_fail_with("expected the group names, then the test name")
}
