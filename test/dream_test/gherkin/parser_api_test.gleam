import dream_test/file
import dream_test/gherkin/parser
import dream_test/gherkin/types as gtypes
import dream_test/matchers.{fail_with}
import dream_test/types as test_types
import dream_test/unit.{describe, it}
import gleam/option.{None}

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
        Ok(gtypes.Feature(
          name: "From File",
          description: _,
          tags: _,
          background: _,
          scenarios: [_],
        )) -> Ok(test_types.AssertionOk)
        Ok(_) -> Ok(fail_with("unexpected parse result"))
        Error(msg) -> Ok(fail_with(msg))
      }
    }),
  ])
}
