//// Matcher for checking a single GherkinScenario test kind.

import dream_test/types.{
  type MatchResult, type TestSuiteItem, AssertionFailure, GherkinScenario,
  MatchFailed, MatchOk, SuiteTest, TestCase,
}
import gleam/option.{None}

/// Assert that a list of suite items contains exactly one GherkinScenario test.
pub fn have_single_gherkin_test(
  items: MatchResult(List(TestSuiteItem)),
) -> MatchResult(Nil) {
  case items {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk([SuiteTest(TestCase(config))]) -> {
      case config.kind {
        GherkinScenario(_) -> MatchOk(Nil)
        _ ->
          MatchFailed(AssertionFailure(
            operator: "have_single_gherkin_test",
            message: "Expected GherkinScenario kind",
            payload: None,
          ))
      }
    }
    MatchOk(_) ->
      MatchFailed(AssertionFailure(
        operator: "have_single_gherkin_test",
        message: "Expected exactly one SuiteTest item",
        payload: None,
      ))
  }
}
