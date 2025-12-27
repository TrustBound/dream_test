import dream_test/gherkin/parser
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/result

pub fn tests() {
  describe("Gherkin parser", [
    it("parse_string parses a minimal feature", fn() {
      let content =
        "@smoke\n"
        <> "Feature: Demo\n"
        <> "\n"
        <> "  Scenario: One\n"
        <> "    Given a thing\n"

      use feature <- result.try(parser.parse_string(content))

      feature.name
      |> should
      |> be_equal("Demo")
      |> or_fail_with("expected feature name Demo")
    }),
  ])
}
