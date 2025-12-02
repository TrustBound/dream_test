//// Matcher for extracting tags from a single test.

import dream_test/types.{
  type MatchResult, type TestSuiteItem, AssertionFailure, MatchFailed, MatchOk,
  SuiteTest, TestCase,
}
import gleam/option.{None}

/// Extract tags from a single test case in a list of suite items.
///
/// Passes the tags to subsequent matchers for further assertions.
pub fn extract_single_test_tags(
  items: MatchResult(List(TestSuiteItem)),
) -> MatchResult(List(String)) {
  case items {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk([SuiteTest(TestCase(config))]) -> MatchOk(config.tags)
    MatchOk(_) ->
      MatchFailed(AssertionFailure(
        operator: "extract_single_test_tags",
        message: "Expected exactly one SuiteTest item",
        payload: None,
      ))
  }
}
