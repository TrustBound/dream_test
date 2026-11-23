import dream_test/gherkin/step_trie
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn quoted_run_stays_one_word() -> Result(AssertionResult, String) {
  step_trie.tokenize_step_text("I add \"Red Widget\" and pay $19.99USD")
  |> should
  |> be_equal(["I", "add", "\"Red Widget\"", "and", "pay", "$19.99USD"])
  |> or_fail_with("expected tokenization to keep the quoted run")
}
