import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn before_all_suites_builder_name() -> Result(AssertionResult, String) {
  types.setup_hook_name(types.BeforeAllSuitesHook)
  |> should
  |> be_equal("before_all_suites")
  |> or_fail_with("expected the builder name")
}
