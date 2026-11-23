import dream_test/gherkin/types.{And, GivenPhase, resolve_phase}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types
import gleam/option.{Some}

pub fn and_after_given_is_a_given_step() -> Result(
  dream_types.AssertionResult,
  String,
) {
  resolve_phase(keyword: And, previous: Some(GivenPhase))
  |> should
  |> be_equal(Ok(GivenPhase))
  |> or_fail_with("expected And after Given to be a Given step")
}
