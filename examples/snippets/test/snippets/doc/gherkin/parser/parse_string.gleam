import dream_test/gherkin/parser
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn minimal_feature_is_named_demo() -> Result(AssertionResult, String) {
  let content =
    "@smoke\n"
    <> "Feature: Demo\n"
    <> "\n"
    <> "  Scenario: One\n"
    <> "    Given a thing\n"

  let assert Ok(feature) = parser.parse_string(content)

  feature.name
  |> should
  |> be_equal("Demo")
  |> or_fail_with("expected feature name Demo")
}
