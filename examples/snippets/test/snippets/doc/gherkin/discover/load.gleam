import dream_test/gherkin/discover
import dream_test/matchers.{have_length, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn load_parses_one_feature() -> Result(AssertionResult, String) {
  let result = discover.features("test/*.feature") |> discover.load()

  result.features
  |> should
  |> have_length(1)
  |> or_fail_with("expected one parsed feature")
}
