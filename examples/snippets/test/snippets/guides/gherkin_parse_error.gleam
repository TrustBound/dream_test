import dream_test/gherkin/parser
import dream_test/gherkin/types.{type Feature}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/result
import snippets_outputs

/// A feature whose first scenario step is `And`, with no step before it.
pub const broken_feature =
  "Feature: Shopping Cart
  Scenario: Adding items
    And I have 3 items in my cart
    When I add 2 more items
    Then I should have 5 items total
"

pub fn parse_broken_feature() -> Result(Feature, String) {
  parser.parse_string(broken_feature)
  |> result.map_error(parser.parse_error_to_string)
}

pub fn tests() {
  describe("A feature that does not parse", [
    it("gives an error that names the line", fn() {
      // Act
      let parsed = parse_broken_feature() |> result.map_error(with_newline)

      // Assert
      Ok(parsed)
      |> should
      |> be_equal(
        snippets_outputs.expected("guide_gherkin_parse_error")
        |> result.map(Error),
      )
      |> or_fail_with("expected test/outputs/guide_gherkin_parse_error.txt")
    }),
  ])
}

/// The output file ends with a newline, and the error text does not.
fn with_newline(text: String) -> String {
  text <> "\n"
}
