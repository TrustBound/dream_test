import dream_test/gherkin/step_trie
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn float_with_prefix_and_suffix_splits_into_segments() -> Result(
  AssertionResult,
  String,
) {
  step_trie.parse_step_pattern("the total is ${float}USD")
  |> should
  |> be_equal([
    [step_trie.LiteralText("the")],
    [step_trie.LiteralText("total")],
    [step_trie.LiteralText("is")],
    [
      step_trie.LiteralText("$"),
      step_trie.FloatParam,
      step_trie.LiteralText("USD"),
    ],
  ])
  |> or_fail_with(
    "expected ${float}USD to split into literal + FloatParam segments",
  )
}
