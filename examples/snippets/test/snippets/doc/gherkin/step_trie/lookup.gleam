import dream_test/gherkin/step_trie
import dream_test/gherkin/types.{ThenPhase}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types
import gleam/option.{Some}
import gleam/result

pub fn total_usd_captures_a_float() -> Result(
  dream_types.AssertionResult,
  String,
) {
  use trie <- result.try(
    step_trie.new()
    |> step_trie.insert(
      phase: ThenPhase,
      pattern: "the total is ${float}USD",
      handler: "total_usd",
    ),
  )

  step_trie.lookup(trie, ThenPhase, "the total is $19.99USD")
  |> should
  |> be_equal(
    Some(
      step_trie.StepMatch(handler: "total_usd", captures: [
        step_trie.CapturedFloat(19.99),
      ]),
    ),
  )
  |> or_fail_with("expected float capture for $19.99USD")
}
