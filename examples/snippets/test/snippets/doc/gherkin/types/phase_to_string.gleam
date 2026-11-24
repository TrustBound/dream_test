import dream_test/gherkin/types.{WhenPhase, phase_to_string}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types

pub fn when_phase_reads_as_when() -> Result(dream_types.AssertionResult, String) {
  phase_to_string(WhenPhase)
  |> should
  |> be_equal("When")
  |> or_fail_with("expected When")
}
