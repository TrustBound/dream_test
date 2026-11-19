import dream_test/file
import dream_test/gherkin/parser.{
  BackgroundLine, DocStringSeparator, EndOfFile, ExamplesLine, FeatureLine,
  InvalidFeatureFile, ParseError, RuleLine, ScenarioLine, StepLine, TableRow,
  TagLine, UnreadableFeatureFile,
}
import dream_test/gherkin/types as gtypes
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, group, it}
import gleam/list
import gleam/option.{None, Some}
import gleam/result

pub fn tests() {
  describe("dream_test/gherkin/parser", [
    group("features", [
      it("parse_string parses a minimal feature", fn() {
        parser.parse_string(
          "@smoke
Feature: Demo

  Scenario: One
    Given a thing
",
        )
        |> should
        |> be_equal(
          Ok(
            gtypes.Feature(
              name: "Demo",
              source: None,
              description: None,
              tags: ["smoke"],
              background: None,
              scenarios: [
                gtypes.Scenario(
                  keyword: gtypes.KeywordScenario,
                  name: "One",
                  description: None,
                  tags: [],
                  steps: [
                    gtypes.Step(
                      keyword: gtypes.Given,
                      text: "a thing",
                      doc_string: None,
                      data_table: None,
                    ),
                  ],
                  examples: [],
                ),
              ],
              rules: [],
            ),
          ),
        )
        |> or_fail_with("expected the minimal feature")
      }),
      it("parse_string reads Business Need as a Feature", fn() {
        parser.parse_string("Business Need: Money\n")
        |> result.map(feature_name)
        |> should
        |> be_equal(Ok("Money"))
        |> or_fail_with("expected the Business Need name")
      }),
      it("parse_string reads Ability as a Feature", fn() {
        parser.parse_string("Ability: Fly\n")
        |> result.map(feature_name)
        |> should
        |> be_equal(Ok("Fly"))
        |> or_fail_with("expected the Ability name")
      }),
      it("parse_string accepts a language line for English", fn() {
        parser.parse_string("# language: en\nFeature: English\n")
        |> result.map(feature_name)
        |> should
        |> be_equal(Ok("English"))
        |> or_fail_with("expected the English feature")
      }),
      it("parse_string ignores a comment that is not a language line", fn() {
        parser.parse_string("# language\nFeature: Commented\n")
        |> result.map(feature_name)
        |> should
        |> be_equal(Ok("Commented"))
        |> or_fail_with("expected the comment to be ignored")
      }),
      it("parse_string ignores a language line with a bad language code", fn() {
        parser.parse_string("# language: e!n\nFeature: Code\n")
        |> result.map(feature_name)
        |> should
        |> be_equal(Ok("Code"))
        |> or_fail_with("expected the comment to be ignored")
      }),
      it("parse_string ignores a language line without a code", fn() {
        parser.parse_string("# language:\nFeature: Empty code\n")
        |> result.map(feature_name)
        |> should
        |> be_equal(Ok("Empty code"))
        |> or_fail_with("expected the comment to be ignored")
      }),
      it("parse_string ignores a language comment without a colon", fn() {
        parser.parse_string("# language en\nFeature: No colon\n")
        |> result.map(feature_name)
        |> should
        |> be_equal(Ok("No colon"))
        |> or_fail_with("expected the comment to be ignored")
      }),
      it("parse_string keeps the leading whitespace of description lines", fn() {
        parser.parse_string(
          "Feature: F
  First line
  # a comment

  Second line

Scenario: S
  Given a
",
        )
        |> result.map(feature_description)
        |> should
        |> be_equal(Ok(Some("  First line\n\n  Second line")))
        |> or_fail_with("expected the raw description lines")
      }),
      it("parse_string reads tags with a comment and joined tags", fn() {
        parser.parse_string("@a@b\t#comment\n@c #more\nFeature: Tagged\n")
        |> result.map(feature_tags)
        |> should
        |> be_equal(Ok(["a", "b", "c"]))
        |> or_fail_with("expected three tags")
      }),
      it("parse_file sets the source to the path", fn() {
        let path = "./test/tmp/features/parser_api_test.feature"
        let _ = file.write(path, "Feature: From File\n")

        parser.parse_file(path)
        |> result.map(feature_source)
        |> should
        |> be_equal(Ok(Some(path)))
        |> or_fail_with("expected the source to be the path")
      }),
      it("parse_file gives UnreadableFeatureFile for a missing file", fn() {
        parser.parse_file("./test/tmp/features/does_not_exist.feature")
        |> should
        |> be_equal(
          Error(
            UnreadableFeatureFile(file.NotFound(
              "./test/tmp/features/does_not_exist.feature",
            )),
          ),
        )
        |> or_fail_with("expected a read error")
      }),
      it("parse_file gives InvalidFeatureFile with the path", fn() {
        let path = "./test/tmp/features/parser_api_invalid.feature"
        let _ = file.write(path, "Scenario: S\n")

        parser.parse_file(path)
        |> should
        |> be_equal(
          Error(InvalidFeatureFile(
            path: path,
            error: ParseError(
              line: 1,
              problem: parser.UnexpectedLine("Scenario: S", [
                TagLine,
                FeatureLine,
              ]),
            ),
          )),
        )
        |> or_fail_with("expected an invalid file error")
      }),
    ]),
    group("lines and tokens", [
      it("parse_string removes the carriage return of CRLF lines", fn() {
        parser.parse_string("Feature: F\r\n  Scenario: S\r\n    Given a\r\n")
        |> result.map(first_scenario_steps)
        |> should
        |> be_equal(Ok([gtypes.Step(gtypes.Given, "a", None, None)]))
        |> or_fail_with("expected the step text without a carriage return")
      }),
      it("parse_string reads a file without a final newline", fn() {
        parser.parse_string("\nFeature: F\n  Scenario: S\n    Given a")
        |> result.map(first_scenario_steps)
        |> should
        |> be_equal(Ok([gtypes.Step(gtypes.Given, "a", None, None)]))
        |> or_fail_with("expected the last step")
      }),
      it("parse_string skips comments between steps", fn() {
        parser.parse_string(
          "Feature: F\n  Scenario: S\n    Given a\n    # note\n    Then b\n",
        )
        |> result.map(first_scenario_steps)
        |> should
        |> be_equal(
          Ok([
            gtypes.Step(gtypes.Given, "a", None, None),
            gtypes.Step(gtypes.Then, "b", None, None),
          ]),
        )
        |> or_fail_with("expected two steps")
      }),
      it("parse_string unescapes table cells", fn() {
        parser.parse_string(
          "Feature: F\n  Scenario: S\n    Given a\n      | a\\|b | c\\\\d | e\\nf | \\x |\n",
        )
        |> result.map(first_scenario_steps)
        |> should
        |> be_equal(
          Ok([
            gtypes.Step(
              gtypes.Given,
              "a",
              None,
              Some(gtypes.DataTable([["a|b", "c\\d", "e\nf", "\\x"]])),
            ),
          ]),
        )
        |> or_fail_with("expected the unescaped cells")
      }),
      it("parse_string rejects a language other than English", fn() {
        parser.parse_string("# language: fr\nFonctionnalité: F\n")
        |> should
        |> be_equal(
          Error(ParseError(line: 1, problem: parser.UnsupportedLanguage("fr"))),
        )
        |> or_fail_with("expected an unsupported language error")
      }),
      it("parse_string ignores a plain comment before the Feature", fn() {
        parser.parse_string("# just a comment\nFeature: Plain\n")
        |> result.map(feature_name)
        |> should
        |> be_equal(Ok("Plain"))
        |> or_fail_with("expected the comment to be ignored")
      }),
      it("parse_string rejects tags at the end of the file", fn() {
        parser.parse_string("Feature: F\n  @tag\n")
        |> should
        |> be_equal(
          Error(ParseError(
            line: 3,
            problem: parser.UnexpectedEndOfFile([
              TagLine,
              ScenarioLine,
              RuleLine,
            ]),
          )),
        )
        |> or_fail_with("expected an end of file error")
      }),
    ]),
    group("backgrounds and rules", [
      it("parse_string reads the name and description of a Background", fn() {
        parser.parse_string(
          "Feature: F
  Background: Setup
    Some words
    Given a
",
        )
        |> result.map(feature_background)
        |> should
        |> be_equal(
          Ok(
            Some(
              gtypes.Background(
                name: "Setup",
                description: Some("    Some words"),
                steps: [gtypes.Step(gtypes.Given, "a", None, None)],
              ),
            ),
          ),
        )
        |> or_fail_with("expected the Background")
      }),
      it("parse_string reads a Rule with a Background and a scenario", fn() {
        parser.parse_string(
          "Feature: F
  @slow
  Rule: Stock
    Words
    Background:
      Given stock
    Example: Sell
      When I sell
",
        )
        |> result.map(feature_rules)
        |> should
        |> be_equal(
          Ok([
            gtypes.Rule(
              name: "Stock",
              description: Some("    Words"),
              tags: ["slow"],
              background: Some(
                gtypes.Background(name: "", description: None, steps: [
                  gtypes.Step(gtypes.Given, "stock", None, None),
                ]),
              ),
              scenarios: [
                gtypes.Scenario(
                  keyword: gtypes.KeywordExample,
                  name: "Sell",
                  description: None,
                  tags: [],
                  steps: [gtypes.Step(gtypes.When, "I sell", None, None)],
                  examples: [],
                ),
              ],
            ),
          ]),
        )
        |> or_fail_with("expected the Rule")
      }),
      it(
        "parse_string lets a Rule scenario start with And after a Feature Background",
        fn() {
          parser.parse_string(
            "Feature: F
  Background:
    Given a
  Rule: R
    Scenario: S
      And b
",
          )
          |> result.map(first_rule_step_count)
          |> should
          |> be_equal(Ok(1))
          |> or_fail_with("expected the And step to parse")
        },
      ),
      it(
        "parse_string lets a Rule Background start with And after a Feature Background",
        fn() {
          parser.parse_string(
            "Feature: F
  Background:
    Given a
  Rule: R
    Background:
      And b
",
          )
          |> result.map(feature_rule_count)
          |> should
          |> be_equal(Ok(1))
          |> or_fail_with("expected the And step to parse")
        },
      ),
      it(
        "parse_string lets a Rule scenario start with And after a Rule Background",
        fn() {
          parser.parse_string(
            "Feature: F
  Rule: R
    Background:
      Given a
    Scenario: S
      But b
",
          )
          |> result.map(first_rule_step_count)
          |> should
          |> be_equal(Ok(1))
          |> or_fail_with("expected the But step to parse")
        },
      ),
      it("parse_string rejects a Rule Background that starts with And", fn() {
        parser.parse_string(
          "Feature: F\n  Rule: R\n    Background:\n      And b\n",
        )
        |> should
        |> be_equal(
          Error(ParseError(
            line: 4,
            problem: parser.MissingPreviousStep(gtypes.And, "b"),
          )),
        )
        |> or_fail_with("expected a missing previous step error")
      }),
      it("parse_string rejects a Background after a scenario", fn() {
        parser.parse_string(
          "Feature: F\n  Scenario: S\n    Given a\n  Background:\n",
        )
        |> should
        |> be_equal(
          Error(ParseError(
            line: 4,
            problem: parser.UnexpectedLine("Background:", [
              StepLine,
              TagLine,
              ExamplesLine,
              ScenarioLine,
              RuleLine,
              EndOfFile,
            ]),
          )),
        )
        |> or_fail_with("expected an unexpected line error")
      }),
      it("parse_string rejects a second Background", fn() {
        parser.parse_string(
          "Feature: F\n  Background:\n    Given a\n  Background:\n",
        )
        |> should
        |> be_equal(
          Error(ParseError(
            line: 4,
            problem: parser.UnexpectedLine("Background:", [
              StepLine,
              TagLine,
              ScenarioLine,
              RuleLine,
              EndOfFile,
            ]),
          )),
        )
        |> or_fail_with("expected an unexpected line error")
      }),
      it("parse_string rejects tags before a Background", fn() {
        parser.parse_string("Feature: F\n  @tag\n  Background:\n")
        |> should
        |> be_equal(
          Error(ParseError(
            line: 3,
            problem: parser.UnexpectedLine("Background:", [
              TagLine,
              ScenarioLine,
              RuleLine,
            ]),
          )),
        )
        |> or_fail_with("expected an unexpected line error")
      }),
      it("parse_string rejects a bad tag in a Rule", fn() {
        parser.parse_string("Feature: F\n  Rule: R\n  @a b\n")
        |> should
        |> be_equal(
          Error(ParseError(
            line: 3,
            problem: parser.TagContainsWhitespace("a b"),
          )),
        )
        |> or_fail_with("expected a tag error")
      }),
      it("parse_string rejects a bad tag after a Background", fn() {
        parser.parse_string("Feature: F\n  Background:\n    Given a\n  @a b\n")
        |> should
        |> be_equal(
          Error(ParseError(
            line: 4,
            problem: parser.TagContainsWhitespace("a b"),
          )),
        )
        |> or_fail_with("expected a tag error")
      }),
      it("parse_string rejects a bad step in a Background", fn() {
        parser.parse_string("Feature: F\n  Background:\n    * a\n")
        |> should
        |> be_equal(
          Error(ParseError(
            line: 3,
            problem: parser.MissingPreviousStep(gtypes.Asterisk, "a"),
          )),
        )
        |> or_fail_with("expected a missing previous step error")
      }),
      it("parse_string rejects a bad step in a Rule scenario", fn() {
        parser.parse_string(
          "Feature: F\n  Rule: R\n    Scenario: S\n      And a\n",
        )
        |> should
        |> be_equal(
          Error(ParseError(
            line: 4,
            problem: parser.MissingPreviousStep(gtypes.And, "a"),
          )),
        )
        |> or_fail_with("expected a missing previous step error")
      }),
    ]),
    group("scenarios and examples", [
      it("parse_string reads every Examples section with its tags", fn() {
        parser.parse_string(
          "Feature: F
  Scenario Template: T
    Given <n>
    @small
    Scenarios: Small
      | n |
      | 1 |
    Examples:
      Words
      | n |
",
        )
        |> result.map(first_scenario_examples)
        |> should
        |> be_equal(
          Ok([
            gtypes.Examples(
              name: "Small",
              description: None,
              tags: ["small"],
              table: Some(gtypes.ExamplesTable(headers: ["n"], rows: [["1"]])),
            ),
            gtypes.Examples(
              name: "",
              description: Some("      Words"),
              tags: [],
              table: Some(gtypes.ExamplesTable(headers: ["n"], rows: [])),
            ),
          ]),
        )
        |> or_fail_with("expected two Examples sections")
      }),
      it("parse_string gives no table to Examples without rows", fn() {
        parser.parse_string(
          "Feature: F\n  Scenario Outline: O\n    Given a\n    Examples:\n",
        )
        |> result.map(first_scenario_examples)
        |> should
        |> be_equal(
          Ok([
            gtypes.Examples(name: "", description: None, tags: [], table: None),
          ]),
        )
        |> or_fail_with("expected Examples without a table")
      }),
      it("parse_string ends a scenario description at an Examples line", fn() {
        parser.parse_string(
          "Feature: F
  Scenario Outline: O
    Words
    Examples: A
      Examples words
    Examples: B
",
        )
        |> result.map(first_scenario_examples)
        |> should
        |> be_equal(
          Ok([
            gtypes.Examples(
              name: "A",
              description: Some("      Examples words"),
              tags: [],
              table: None,
            ),
            gtypes.Examples(name: "B", description: None, tags: [], table: None),
          ]),
        )
        |> or_fail_with("expected two Examples sections")
      }),
      it("parse_string keeps empty table cells", fn() {
        parser.parse_string(
          "Feature: F\n  Scenario: S\n    Given a\n      | x || y |\n",
        )
        |> result.map(first_scenario_steps)
        |> should
        |> be_equal(
          Ok([
            gtypes.Step(
              gtypes.Given,
              "a",
              None,
              Some(gtypes.DataTable([["x", "", "y"]])),
            ),
          ]),
        )
        |> or_fail_with("expected the empty cell")
      }),
      it("parse_string reads a DocString with a media type", fn() {
        parser.parse_string(
          "Feature: F
  Scenario: S
    Given a
      ```json
      {}
      ```
",
        )
        |> result.map(first_scenario_steps)
        |> should
        |> be_equal(
          Ok([
            gtypes.Step(
              gtypes.Given,
              "a",
              Some(gtypes.DocString("{}", Some("json"))),
              None,
            ),
          ]),
        )
        |> or_fail_with("expected the DocString")
      }),
      it("parse_string rejects a step after an Examples table", fn() {
        parser.parse_string(
          "Feature: F
  Scenario Outline: O
    Given <n>
    Examples:
      | n |
    Given more
",
        )
        |> should
        |> be_equal(
          Error(ParseError(
            line: 6,
            problem: parser.UnexpectedLine("Given more", [
              TableRow,
              TagLine,
              ExamplesLine,
              ScenarioLine,
              RuleLine,
              EndOfFile,
            ]),
          )),
        )
        |> or_fail_with("expected an unexpected line error")
      }),
      it("parse_string rejects a bad Examples tag", fn() {
        parser.parse_string(
          "Feature: F\n  Scenario: S\n    Given a\n    @a b\n    Examples:\n",
        )
        |> should
        |> be_equal(
          Error(ParseError(
            line: 4,
            problem: parser.TagContainsWhitespace("a b"),
          )),
        )
        |> or_fail_with("expected a tag error")
      }),
      it("parse_string rejects a bad tag after an Examples table", fn() {
        parser.parse_string(
          "Feature: F
  Scenario: S
    Given a
    Examples:
      | n |
    @a b
",
        )
        |> should
        |> be_equal(
          Error(ParseError(
            line: 6,
            problem: parser.TagContainsWhitespace("a b"),
          )),
        )
        |> or_fail_with("expected a tag error")
      }),
      it("parse_string rejects an inconsistent Examples row", fn() {
        parser.parse_string(
          "Feature: F
  Scenario: S
    Given a
    Examples:
      | n |
      | 1 | 2 |
",
        )
        |> should
        |> be_equal(
          Error(ParseError(line: 6, problem: parser.InconsistentCellCount(1, 2))),
        )
        |> or_fail_with("expected a cell count error")
      }),
      it("parse_string rejects a bad step in a second scenario", fn() {
        parser.parse_string(
          "Feature: F\n  Scenario: A\n    Given a\n  Scenario: B\n    And b\n",
        )
        |> should
        |> be_equal(
          Error(ParseError(
            line: 5,
            problem: parser.MissingPreviousStep(gtypes.And, "b"),
          )),
        )
        |> or_fail_with("expected a missing previous step error")
      }),
    ]),
    group("step arguments", [
      it(
        "parse_string keeps a DocString and the DataTable after it on one step",
        fn() {
          parser.parse_string(
            "Feature: F
Scenario: S
  Given text
    \"\"\"
    hello
    \"\"\"
    | a |
",
          )
          |> result.map(first_scenario_steps)
          |> should
          |> be_equal(
            Ok([
              gtypes.Step(
                gtypes.Given,
                "text",
                Some(gtypes.DocString("hello", None)),
                Some(gtypes.DataTable([["a"]])),
              ),
            ]),
          )
          |> or_fail_with("expected both step arguments")
        },
      ),
      it(
        "parse_string keeps a DataTable and the DocString after it on one step",
        fn() {
          parser.parse_string(
            "Feature: F
Scenario: S
  Given text
    | a |
    \"\"\"
    hello
    \"\"\"
",
          )
          |> result.map(first_scenario_steps)
          |> should
          |> be_equal(
            Ok([
              gtypes.Step(
                gtypes.Given,
                "text",
                Some(gtypes.DocString("hello", None)),
                Some(gtypes.DataTable([["a"]])),
              ),
            ]),
          )
          |> or_fail_with("expected both step arguments")
        },
      ),
      it("parse_string rejects a second DocString on one step", fn() {
        parser.parse_string(
          "Feature: F
Scenario: S
  Given text
    \"\"\"
    one
    \"\"\"
    \"\"\"
    two
    \"\"\"
",
        )
        |> should
        |> be_equal(
          Error(ParseError(line: 7, problem: parser.RepeatedDocString)),
        )
        |> or_fail_with("expected a repeated DocString error")
      }),
      it(
        "parse_string rejects a second DocString after a DataTable and a DocString",
        fn() {
          parser.parse_string(
            "Feature: F
Scenario: S
  Given text
    | a |
    \"\"\"
    one
    \"\"\"
    \"\"\"
    two
    \"\"\"
",
          )
          |> should
          |> be_equal(
            Error(ParseError(line: 8, problem: parser.RepeatedDocString)),
          )
          |> or_fail_with("expected a repeated DocString error")
        },
      ),
      it("parse_string rejects an unclosed DocString after a DataTable", fn() {
        parser.parse_string(
          "Feature: F
Scenario: S
  Given text
    | a |
    \"\"\"
    one
",
        )
        |> should
        |> be_equal(
          Error(ParseError(line: 7, problem: parser.UnclosedDocString(5))),
        )
        |> or_fail_with("expected an unclosed DocString error")
      }),
      it("parse_string rejects a short table row after a DocString", fn() {
        parser.parse_string(
          "Feature: F
Scenario: S
  Given text
    \"\"\"
    one
    \"\"\"
    | a | b |
    | c |
",
        )
        |> should
        |> be_equal(
          Error(ParseError(line: 8, problem: parser.InconsistentCellCount(2, 1))),
        )
        |> or_fail_with("expected an inconsistent cell count error")
      }),
      it(
        "parse_string rejects a DataTable after a DataTable and a DocString",
        fn() {
          parser.parse_string(
            "Feature: F
Scenario: S
  Given text
    | a |
    \"\"\"
    one
    \"\"\"
    | b |
",
          )
          |> should
          |> be_equal(
            Error(ParseError(
              line: 8,
              problem: parser.UnexpectedLine("| b |", [
                StepLine,
                TagLine,
                ExamplesLine,
                ScenarioLine,
                RuleLine,
                EndOfFile,
              ]),
            )),
          )
          |> or_fail_with("expected an unexpected line error")
        },
      ),
      it(
        "parse_string removes the separator indentation and unescapes a separator",
        fn() {
          parser.parse_string(
            "Feature: F
Scenario: S
  Given text
    \"\"\"
      deeper
  shallow
    a \\\"\\\"\\\" b
    \"\"\"
",
          )
          |> result.map(first_scenario_steps)
          |> should
          |> be_equal(
            Ok([
              gtypes.Step(
                gtypes.Given,
                "text",
                Some(gtypes.DocString("  deeper\nshallow\na \"\"\" b", None)),
                None,
              ),
            ]),
          )
          |> or_fail_with("expected the DocString content")
        },
      ),
      it("parse_string unescapes every escaped separator of a line", fn() {
        parser.parse_string(
          "Feature: F
Scenario: S
  Given text
    ```
    a \\`\\`\\` b \\`\\`\\` c
    ```
",
        )
        |> result.map(first_scenario_steps)
        |> should
        |> be_equal(
          Ok([
            gtypes.Step(
              gtypes.Given,
              "text",
              Some(gtypes.DocString("a ``` b ``` c", None)),
              None,
            ),
          ]),
        )
        |> or_fail_with("expected both separators unescaped")
      }),
      it("parse_string rejects an inconsistent DataTable row", fn() {
        parser.parse_string(
          "Feature: F\nScenario: S\n  Given text\n    | a |\n    | b | c |\n",
        )
        |> should
        |> be_equal(
          Error(ParseError(line: 5, problem: parser.InconsistentCellCount(1, 2))),
        )
        |> or_fail_with("expected a cell count error")
      }),
      it("parse_string rejects a DocString that is not closed", fn() {
        parser.parse_string(
          "Feature: F\nScenario: S\n  Given text\n    \"\"\"\n    hello\n",
        )
        |> should
        |> be_equal(
          Error(ParseError(line: 6, problem: parser.UnclosedDocString(4))),
        )
        |> or_fail_with("expected an unclosed DocString error")
      }),
    ]),
    group("leading conjunctions", [
      it("parse_string rejects a Scenario that starts with And", fn() {
        parser.parse_string("Feature: F\nScenario: S\n  And a\n")
        |> should
        |> be_equal(
          Error(ParseError(
            line: 3,
            problem: parser.MissingPreviousStep(gtypes.And, "a"),
          )),
        )
        |> or_fail_with("expected a missing previous step error")
      }),
      it("parse_string rejects a leading And after an empty Background", fn() {
        parser.parse_string("Feature: F\nBackground:\nScenario: S\n  And a\n")
        |> should
        |> be_equal(
          Error(ParseError(
            line: 4,
            problem: parser.MissingPreviousStep(gtypes.And, "a"),
          )),
        )
        |> or_fail_with("expected a missing previous step error")
      }),
    ]),
    group("rendering", [
      it("token_kind_to_string describes every kind", fn() {
        [
          FeatureLine,
          RuleLine,
          BackgroundLine,
          ScenarioLine,
          ExamplesLine,
          StepLine,
          TableRow,
          DocStringSeparator,
          TagLine,
          EndOfFile,
        ]
        |> list.map(parser.token_kind_to_string)
        |> should
        |> be_equal([
          "a Feature line",
          "a Rule line",
          "a Background line",
          "a Scenario line",
          "an Examples line",
          "a step",
          "a table row",
          "a DocString separator",
          "a tag line",
          "the end of the file",
        ])
        |> or_fail_with("expected every description")
      }),
      it("problem_to_string renders every problem", fn() {
        [
          parser.MissingFeature,
          parser.UnexpectedLine("x", [TagLine, FeatureLine]),
          parser.UnexpectedEndOfFile([TagLine, ScenarioLine, RuleLine]),
          parser.UnexpectedEndOfFile([]),
          parser.UnclosedDocString(4),
          parser.InconsistentCellCount(2, 1),
          parser.TagContainsWhitespace("a b"),
          parser.UnsupportedLanguage("fr"),
          parser.RepeatedDocString,
          parser.MissingPreviousStep(gtypes.But, "b"),
        ]
        |> list.map(parser.problem_to_string)
        |> should
        |> be_equal([
          "No Feature found in content",
          "Found \"x\", but expected a tag line or a Feature line.",
          "The file ends here, but expected a tag line, a Scenario line or a Rule line.",
          "The file ends here, but expected nothing.",
          "The DocString that starts on line 4 is not closed",
          "This table row has 1 cells, but the first row of the table has 2 cells",
          "The tag \"@a b\" contains whitespace. A tag cannot contain whitespace.",
          "The language \"fr\" is not supported. dream_test supports only English (\"en\").",
          "Step cannot have more than one DocString",
          "\"But b\" has no step before it. And, But and * take the phase of the step before them, so the first step of a Background, or of a Scenario with no Background steps, must use Given, When or Then.",
        ])
        |> or_fail_with("expected every message")
      }),
      it("parse_error_to_string starts with the line", fn() {
        parser.parse_error_to_string(ParseError(
          line: 3,
          problem: parser.RepeatedDocString,
        ))
        |> should
        |> be_equal("line 3: Step cannot have more than one DocString")
        |> or_fail_with("expected the line prefix")
      }),
      it(
        "feature_file_error_to_string starts an invalid file with the path",
        fn() {
          parser.feature_file_error_to_string(InvalidFeatureFile(
            path: "a.feature",
            error: ParseError(line: 1, problem: parser.MissingFeature),
          ))
          |> should
          |> be_equal("a.feature: line 1: No Feature found in content")
          |> or_fail_with("expected the path prefix")
        },
      ),
      it("feature_file_error_to_string names an unreadable file", fn() {
        parser.feature_file_error_to_string(
          UnreadableFeatureFile(file.NotFound("a.feature")),
        )
        |> should
        |> be_equal("Failed to read feature file: File not found: a.feature")
        |> or_fail_with("expected the read error message")
      }),
      it("parse_string rejects a bad tag before the Feature", fn() {
        parser.parse_string("@a b\nFeature: F\n")
        |> should
        |> be_equal(
          Error(ParseError(
            line: 1,
            problem: parser.TagContainsWhitespace("a b"),
          )),
        )
        |> or_fail_with("expected a tag error")
      }),
      it("problem_to_string names a single expected kind", fn() {
        parser.problem_to_string(parser.UnexpectedEndOfFile([FeatureLine]))
        |> should
        |> be_equal("The file ends here, but expected a Feature line.")
        |> or_fail_with("expected one kind")
      }),
      it(
        "parse_string gives MissingFeature for only comments and empty lines",
        fn() {
          parser.parse_string("# language: en\n\n# a comment\n")
          |> should
          |> be_equal(
            Error(ParseError(line: 4, problem: parser.MissingFeature)),
          )
          |> or_fail_with("expected a missing Feature error")
        },
      ),
      it("parse_string gives UnexpectedLine for text without a Feature", fn() {
        parser.parse_string("not gherkin\n")
        |> should
        |> be_equal(
          Error(ParseError(
            line: 1,
            problem: parser.UnexpectedLine("not gherkin", [TagLine, FeatureLine]),
          )),
        )
        |> or_fail_with("expected an unexpected line error")
      }),
      it(
        "parse_string gives UnexpectedEndOfFile for tags without a Feature",
        fn() {
          parser.parse_string("@a\n")
          |> should
          |> be_equal(
            Error(ParseError(
              line: 2,
              problem: parser.UnexpectedEndOfFile([TagLine, FeatureLine]),
            )),
          )
          |> or_fail_with("expected an end of file error")
        },
      ),
      it("parse_string gives MissingFeature for an empty file", fn() {
        parser.parse_string("")
        |> should
        |> be_equal(Error(ParseError(line: 1, problem: parser.MissingFeature)))
        |> or_fail_with("expected a missing feature error")
      }),
    ]),
  ])
}

fn feature_name(feature: gtypes.Feature) -> String {
  feature.name
}

fn feature_description(feature: gtypes.Feature) -> option.Option(String) {
  feature.description
}

fn feature_tags(feature: gtypes.Feature) -> List(String) {
  feature.tags
}

fn feature_source(feature: gtypes.Feature) -> option.Option(String) {
  feature.source
}

fn feature_background(
  feature: gtypes.Feature,
) -> option.Option(gtypes.Background) {
  feature.background
}

fn feature_rules(feature: gtypes.Feature) -> List(gtypes.Rule) {
  feature.rules
}

fn feature_rule_count(feature: gtypes.Feature) -> Int {
  list.length(feature.rules)
}

fn first_rule_step_count(feature: gtypes.Feature) -> Int {
  case feature.rules {
    [gtypes.Rule(scenarios: [scenario, ..], ..), ..] ->
      list.length(scenario.steps)
    _ -> 0
  }
}

fn first_scenario_steps(feature: gtypes.Feature) -> List(gtypes.Step) {
  case feature.scenarios {
    [first, ..] -> first.steps
    [] -> []
  }
}

fn first_scenario_examples(feature: gtypes.Feature) -> List(gtypes.Examples) {
  case feature.scenarios {
    [first, ..] -> first.examples
    [] -> []
  }
}
