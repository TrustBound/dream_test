import dream_test/file
import dream_test/gherkin/parser
import dream_test/gherkin/types as gtypes
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should}
import dream_test/types as test_types
import dream_test/unit.{describe, it}
import gleam/option.{type Option, None, Some}
import gleam/result

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

    it("parse_string keeps a two-line description and skips comments", fn() {
      let content =
        "Feature: F\n"
        <> "  First line\n"
        <> "  Second line\n"
        <> "  # a comment\n"
        <> "Scenario: S\n"
        <> "  Given a\n"

      parser.parse_string(content)
      |> should
      |> be_equal(
        Ok(
          gtypes.Feature(
            name: "F",
            source: None,
            description: Some("First line\nSecond line"),
            tags: [],
            background: None,
            scenarios: [
              gtypes.Scenario(name: "S", tags: [], steps: [
                gtypes.Step(keyword: gtypes.Given, text: "a", argument: None),
              ]),
            ],
          ),
        ),
      )
      |> or_fail_with("description lines should join and comments should go")
    }),

    it("parse_string reads a Background and Then/And/But steps", fn() {
      let content =
        "Feature: F\n"
        <> "Background:\n"
        <> "  Given base\n"
        <> "Scenario: S\n"
        <> "  Then x\n"
        <> "  And y\n"
        <> "  But z\n"

      parser.parse_string(content)
      |> should
      |> be_equal(
        Ok(
          gtypes.Feature(
            name: "F",
            source: None,
            description: None,
            tags: [],
            background: Some(
              gtypes.Background(steps: [
                gtypes.Step(keyword: gtypes.Given, text: "base", argument: None),
              ]),
            ),
            scenarios: [
              gtypes.Scenario(name: "S", tags: [], steps: [
                gtypes.Step(keyword: gtypes.Then, text: "x", argument: None),
                gtypes.Step(keyword: gtypes.And, text: "y", argument: None),
                gtypes.Step(keyword: gtypes.But, text: "z", argument: None),
              ]),
            ],
          ),
        ),
      )
      |> or_fail_with("background and Then/And/But steps should parse")
    }),

    it("parse_string gives no Background for an empty Background", fn() {
      let content =
        "Feature: F\n" <> "Background:\n" <> "Scenario: S\n" <> "  Given a\n"

      parser.parse_string(content)
      |> should
      |> be_equal(
        Ok(
          gtypes.Feature(
            name: "F",
            source: None,
            description: None,
            tags: [],
            background: None,
            scenarios: [
              gtypes.Scenario(name: "S", tags: [], steps: [
                gtypes.Step(keyword: gtypes.Given, text: "a", argument: None),
              ]),
            ],
          ),
        ),
      )
      |> or_fail_with("an empty background should give None")
    }),

    it("parse_string attaches a DocString with a content type", fn() {
      let content =
        "Feature: F\n"
        <> "Scenario: S\n"
        <> "  Given text\n"
        <> "\"\"\"json\n"
        <> "{\"a\": 1}\n"
        <> "\"\"\"\n"

      parser.parse_string(content)
      |> should
      |> be_equal(
        Ok(
          gtypes.Feature(
            name: "F",
            source: None,
            description: None,
            tags: [],
            background: None,
            scenarios: [
              gtypes.Scenario(name: "S", tags: [], steps: [
                gtypes.Step(
                  keyword: gtypes.Given,
                  text: "text",
                  argument: Some(gtypes.DocString(
                    content: "{\"a\": 1}",
                    content_type: Some("json"),
                  )),
                ),
              ]),
            ],
          ),
        ),
      )
      |> or_fail_with("the doc string should attach with its content type")
    }),

    it("parse_string attaches a two-row DataTable", fn() {
      let content =
        "Feature: F\n"
        <> "Scenario: S\n"
        <> "  Given rows\n"
        <> "    | a | b |\n"
        <> "    | c | d |\n"

      parser.parse_string(content)
      |> should
      |> be_equal(
        Ok(
          gtypes.Feature(
            name: "F",
            source: None,
            description: None,
            tags: [],
            background: None,
            scenarios: [
              gtypes.Scenario(name: "S", tags: [], steps: [
                gtypes.Step(
                  keyword: gtypes.Given,
                  text: "rows",
                  argument: Some(
                    gtypes.DataTable(rows: [["a", "b"], ["c", "d"]]),
                  ),
                ),
              ]),
            ],
          ),
        ),
      )
      |> or_fail_with("both table rows should attach to the step")
    }),

    it("parse_string rejects a DocString without a step", fn() {
      let content = "Feature: F\n" <> "\"\"\"\n" <> "x\n" <> "\"\"\"\n"

      parser.parse_string(content)
      |> should
      |> be_equal(Error("DocString without preceding step"))
      |> or_fail_with("a doc string needs a step")
    }),

    it("parse_string rejects a DataTable without a step", fn() {
      let content = "Feature: F\n" <> "| a |\n"

      parser.parse_string(content)
      |> should
      |> be_equal(Error("DataTable without preceding step"))
      |> or_fail_with("a table needs a step")
    }),

    it("parse_string reads a Scenario Outline with Examples", fn() {
      let content =
        "Feature: F\n"
        <> "Scenario Outline: O\n"
        <> "  Given <n>\n"
        <> "Examples:\n"
        <> "  | n |\n"
        <> "  | 1 |\n"
        <> "  | 2 |\n"

      parser.parse_string(content)
      |> should
      |> be_equal(
        Ok(
          gtypes.Feature(
            name: "F",
            source: None,
            description: None,
            tags: [],
            background: None,
            scenarios: [
              gtypes.ScenarioOutline(
                name: "O",
                tags: [],
                steps: [
                  gtypes.Step(
                    keyword: gtypes.Given,
                    text: "<n>",
                    argument: None,
                  ),
                ],
                examples: gtypes.ExamplesTable(headers: ["n"], rows: [
                  ["1"],
                  ["2"],
                ]),
              ),
            ],
          ),
        ),
      )
      |> or_fail_with("the outline should keep its examples")
    }),

    it("parse_string gives an empty table to an outline without Examples", fn() {
      let content = "Feature: F\n" <> "Scenario Outline: O\n" <> "  Given a\n"

      parser.parse_string(content)
      |> should
      |> be_equal(
        Ok(
          gtypes.Feature(
            name: "F",
            source: None,
            description: None,
            tags: [],
            background: None,
            scenarios: [
              gtypes.ScenarioOutline(
                name: "O",
                tags: [],
                steps: [
                  gtypes.Step(keyword: gtypes.Given, text: "a", argument: None),
                ],
                examples: gtypes.ExamplesTable(headers: [], rows: []),
              ),
            ],
          ),
        ),
      )
      |> or_fail_with("an outline without examples should get an empty table")
    }),

    it("parse_file returns an error for a missing file", fn() {
      parser.parse_file("./test/tmp/features/parser_api_missing.feature")
      |> should
      |> be_equal(Error(
        "Failed to read feature file: File not found: ./test/tmp/features/parser_api_missing.feature",
      ))
      |> or_fail_with("a missing file should give a read error")
    }),

    it("parse_string rejects a second DocString on one step", fn() {
      let content =
        "Feature: F\nScenario: S\n  Given text\n    \"\"\"\n    one\n    \"\"\"\n    \"\"\"\n    two\n    \"\"\"\n"

      parser.parse_string(content)
      |> should
      |> be_equal(Error("Step cannot have more than one DocString"))
      |> or_fail_with("a second DocString should be a parse error")
    }),

    it(
      "parse_string removes the delimiter indentation from DocString lines",
      fn() {
        let content =
          "Feature: F\nScenario: S\n  Given text\n    \"\"\"\n    one\n      two\n\n   three\n    \"\"\"\n"

        parser.parse_string(content)
        |> result.map(first_scenario_steps)
        |> should
        |> be_equal(
          Ok([
            gtypes.Step(
              keyword: gtypes.Given,
              text: "text",
              argument: Some(gtypes.DocString(
                content: "one\n  two\n\nthree",
                content_type: None,
              )),
            ),
          ]),
        )
        |> or_fail_with(
          "each line should lose the indentation of the delimiter",
        )
      },
    ),

    it("parse_string reads the steps of a Background with a name", fn() {
      let content =
        "Feature: F\n  Background: Logged in\n    Given a user\n  Scenario: S\n    Then it works\n"

      parser.parse_string(content)
      |> result.map(background_of)
      |> should
      |> be_equal(
        Ok(
          Some(
            gtypes.Background(steps: [
              gtypes.Step(keyword: gtypes.Given, text: "a user", argument: None),
            ]),
          ),
        ),
      )
      |> or_fail_with("a named Background should hold its steps")
    }),

    it("parse_string reads the Examples table of an Examples with a name", fn() {
      let content =
        "Feature: F\n  Scenario Outline: O\n    Given <n>\n    Examples: Small numbers\n      | n |\n      | 1 |\n"

      parser.parse_string(content)
      |> result.map(first_scenario_examples)
      |> should
      |> be_equal(Ok(Some(gtypes.ExamplesTable(headers: ["n"], rows: [["1"]]))))
      |> or_fail_with("a named Examples should hold its table")
    }),
  ])
}

fn first_scenario_steps(feature: gtypes.Feature) -> List(gtypes.Step) {
  case feature.scenarios {
    [first, ..] -> first.steps
    [] -> []
  }
}

fn background_of(feature: gtypes.Feature) -> Option(gtypes.Background) {
  feature.background
}

fn first_scenario_examples(
  feature: gtypes.Feature,
) -> Option(gtypes.ExamplesTable) {
  case feature.scenarios {
    [gtypes.ScenarioOutline(examples: examples, ..), ..] -> Some(examples)
    _ -> None
  }
}
