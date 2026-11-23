import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn after_each_suite_builder_name() -> Result(AssertionResult, String) {
  types.teardown_hook_name(types.AfterEachSuiteHook)
  |> should
  |> be_equal("after_each_suite")
  |> or_fail_with("expected the builder name")
}
