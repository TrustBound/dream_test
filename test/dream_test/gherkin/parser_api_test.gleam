import dream_test/file
import dream_test/gherkin/parser
import dream_test/gherkin/types as gtypes
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should}
import dream_test/types as test_types
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}

pub fn tests() {
  describe("dream_test/gherkin/parser", [
    it("parse_string parses a minimal feature", fn() {
      // Arrange
      let content =
        "@smoke\n"
        <> "Feature: Demo\n"
        <> "\n"
        <> "  Scenario: One\n"
        <> "    Given a thing\n"

      // Act
      let result = parser.parse_string(content)

      // Assert
      case result {
        Ok(gtypes.Feature(
          name: "Demo",
          source: None,
          description: None,
          tags: ["smoke"],
          background: None,
          scenarios: [
            gtypes.Scenario(
              name: "One",
              tags: [],
              steps: [
                gtypes.Step(
                  keyword: gtypes.Given,
                  text: "a thing",
                  argument: None,
                ),
              ],
            ),
          ],
        )) -> Ok(test_types.AssertionOk)

        Ok(_) -> Ok(fail_with("unexpected parse result"))
        Error(msg) -> Ok(fail_with(msg))
      }
    }),

    it("parse_file reads and parses a .feature file", fn() {
      let path = "./test/tmp/features/parser_api_test.feature"
      let content =
        "Feature: From File\n"
        <> "\n"
        <> "Scenario: One\n"
        <> "  Given file input\n"

      let _ = file.write(path, content)

      case parser.parse_file(path) {
        Ok(feature) ->
          case feature.source {
            Some(source) ->
              case source == path && feature.name == "From File" {
                True -> Ok(test_types.AssertionOk)
                False -> Ok(fail_with("unexpected parse result"))
              }
            None -> Ok(fail_with("expected source to be set"))
          }
        Error(msg) -> Ok(fail_with(msg))
      }
    }),

    it("parse_string rejects a DataTable after a DocString on one step", fn() {
      let content =
        "Feature: F\n"
        <> "Scenario: S\n"
        <> "  Given text\n"
        <> "    \"\"\"\n"
        <> "    hello\n"
        <> "    \"\"\"\n"
        <> "    | a |\n"

      parser.parse_string(content)
      |> should
      |> be_equal(Error("Step cannot have both a DataTable and a DocString"))
      |> or_fail_with("a table after a doc string should be an error")
    }),

    it("parse_string rejects a DocString after a DataTable on one step", fn() {
      let content =
        "Feature: F\n"
        <> "Scenario: S\n"
        <> "  Given text\n"
        <> "    | a |\n"
        <> "    \"\"\"\n"
        <> "    hello\n"
        <> "    \"\"\"\n"

      parser.parse_string(content)
      |> should
      |> be_equal(Error("Step cannot have both a DataTable and a DocString"))
      |> or_fail_with("a doc string after a table should be an error")
    }),

    it("parse_string rejects a DocString that is not closed", fn() {
      let content =
        "Feature: F\n"
        <> "Scenario: S\n"
        <> "  Given text\n"
        <> "    \"\"\"\n"
        <> "    hello\n"
        <> "Scenario: Lost\n"
        <> "  Given more\n"

      parser.parse_string(content)
      |> should
      |> be_equal(Error("DocString is not closed"))
      |> or_fail_with("an unclosed doc string should be an error")
    }),
  ])
}
