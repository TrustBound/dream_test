import dream_test/gherkin/types.{Background, empty_background}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types
import gleam/option.{None}

pub fn empty_background_has_no_steps() -> Result(
  dream_types.AssertionResult,
  String,
) {
  empty_background()
  |> should
  |> be_equal(Background(name: "", description: None, steps: []))
  |> or_fail_with("expected empty background")
}
