//// Conformance tests against the official Gherkin test files.
////
//// The fixtures in `test/fixtures/gherkin_conformance` come from the
//// cucumber/gherkin repository. See the README there for the source, the
//// license and the files that are not here.
////
//// Each good file has a `.expected` file. A script made it from the
//// official `.ast.ndjson` file of the same name. The test renders the parsed
//// Feature in the same text format and compares the two texts.

import dream_test/file
import dream_test/gherkin/parser.{
  ExamplesLine, FeatureLine, InconsistentCellCount, InvalidFeatureFile,
  MissingFeature, MissingPreviousStep, ParseError, RepeatedDocString, RuleLine,
  ScenarioLine, StepArgumentConflict, TagContainsWhitespace, TagLine,
  UnclosedDocString, UnexpectedEndOfFile, UnexpectedLine, UnsupportedLanguage,
}
import dream_test/gherkin/types as gherkin_types
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, group, it}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

const good_directory = "test/fixtures/gherkin_conformance/good/"

const good_files = [
  "background", "complex_background", "datatables", "datatables_with_new_lines",
  "descriptions.crlf", "descriptions", "descriptions_with_comments",
  "docstrings.crlf", "docstrings", "escaped_pipes", "example_token_multiple",
  "example_tokens_everywhere", "extra_table_content", "incomplete_feature_1",
  "incomplete_feature_2", "language", "minimal-example", "minimal.crlf",
  "minimal", "padded_example", "readme_example", "rule", "rule_with_tag",
  "rule_without_name_and_description", "scenario_outline",
  "scenario_outline_no_newline", "scenario_outline_with_docstring",
  "scenario_outline_with_value_with_dollar_sign",
  "scenario_outline_with_value_with_trailing_backslash",
  "scenario_outlines_with_tags", "several_examples",
  "tagged_feature_with_scenario_outline", "tags", "trim_space", "trim_tab",
  "very_long",
]

pub fn tests() {
  describe("Gherkin conformance", [
    group("good files", list.map(good_files, good_file_test)),
    group("bad files", [
      bad_file_test(
        "test/fixtures/gherkin_conformance/bad/backslash_at_end_of_line_in_datatable.feature",
        ParseError(line: 5, problem: InconsistentCellCount(1, 0)),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/bad/file_ends_with_open_docstring.feature",
        ParseError(line: 5, problem: UnclosedDocString(opened_on_line: 4)),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/bad/inconsistent_cell_count.feature",
        ParseError(line: 6, problem: InconsistentCellCount(2, 1)),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/bad/invalid_language.feature",
        ParseError(line: 1, problem: UnsupportedLanguage("no-such")),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/bad/multiple_parser_errors.feature",
        ParseError(
          line: 2,
          problem: UnexpectedLine("invalid line here", [TagLine, FeatureLine]),
        ),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/bad/not_gherkin.feature",
        ParseError(
          line: 1,
          problem: UnexpectedLine("not gherkin", [TagLine, FeatureLine]),
        ),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/bad/repeated_step_docstring.feature",
        ParseError(line: 8, problem: RepeatedDocString),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/bad/single_parser_error.feature",
        ParseError(
          line: 2,
          problem: UnexpectedLine("invalid line here", [TagLine, FeatureLine]),
        ),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/bad/unexpected_end_of_file.feature",
        ParseError(
          line: 3,
          problem: UnexpectedEndOfFile([TagLine, ScenarioLine, RuleLine]),
        ),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/bad/unexpected_eof.feature",
        ParseError(
          line: 7,
          problem: UnexpectedEndOfFile([
            TagLine,
            ExamplesLine,
            ScenarioLine,
            RuleLine,
          ]),
        ),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/bad/unfinished_datatable.feature",
        ParseError(line: 5, problem: InconsistentCellCount(1, 0)),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/bad/whitespace_in_tags.feature",
        ParseError(
          line: 3,
          problem: TagContainsWhitespace("a tag containing whitespace"),
        ),
      ),
    ]),
    group("good files that dream_test rejects on purpose", [
      bad_file_test(
        "test/fixtures/gherkin_conformance/differs/conjunctions.feature",
        ParseError(
          line: 18,
          problem: MissingPreviousStep(gherkin_types.Asterisk, "a"),
        ),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/differs/star-keywords.feature",
        ParseError(
          line: 7,
          problem: MissingPreviousStep(gherkin_types.Asterisk, "Betelgeuse"),
        ),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/differs/incomplete_background_1.feature",
        ParseError(
          line: 6,
          problem: MissingPreviousStep(gherkin_types.Asterisk, "a step"),
        ),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/differs/incomplete_background_2.feature",
        ParseError(
          line: 7,
          problem: MissingPreviousStep(gherkin_types.Asterisk, "a step"),
        ),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/differs/incomplete_scenario.feature",
        ParseError(
          line: 4,
          problem: MissingPreviousStep(gherkin_types.Asterisk, "a step"),
        ),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/differs/incomplete_scenario_outline.feature",
        ParseError(
          line: 4,
          problem: MissingPreviousStep(gherkin_types.Asterisk, "a step"),
        ),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/differs/empty.feature",
        ParseError(line: 1, problem: MissingFeature),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/differs/incomplete_feature_3.feature",
        ParseError(line: 2, problem: MissingFeature),
      ),
      bad_file_test(
        "test/fixtures/gherkin_conformance/differs/step_with_datatable_and_docstring.feature",
        ParseError(line: 7, problem: StepArgumentConflict),
      ),
    ]),
  ])
}

fn good_file_test(name: String) {
  it(name, fn() {
    let feature_path = good_directory <> name <> ".feature"
    let expected_path = good_directory <> name <> ".expected"

    render_file(feature_path)
    |> should
    |> be_equal(file.read(expected_path))
    |> or_fail_with("expected the parsed Feature to match the official AST")
  })
}

fn bad_file_test(path: String, expected: parser.ParseError) {
  it(path, fn() {
    parser.parse_file(path)
    |> should
    |> be_equal(Error(InvalidFeatureFile(path: path, error: expected)))
    |> or_fail_with("expected the parse error of the official test file")
  })
}

// ============================================================================
// Canonical rendering (the same format as the .expected files)
// ============================================================================

fn render_file(path: String) -> Result(String, file.FileError) {
  case parser.parse_file(path) {
    Ok(feature) -> Ok(render_feature(feature))
    Error(error) -> Ok(parser.feature_file_error_to_string(error))
  }
}

fn render_feature(feature: gherkin_types.Feature) -> String {
  let lines =
    list.flatten([
      [line(0, "feature " <> quote(feature.name))],
      render_tags(1, feature.tags),
      render_description(1, feature.description),
      render_background(1, feature.background),
      list.flat_map(feature.scenarios, render_scenario(1, _)),
      list.flat_map(feature.rules, render_rule),
    ])
  string.join(lines, "\n") <> "\n"
}

fn render_rule(rule: gherkin_types.Rule) -> List(String) {
  list.flatten([
    [line(1, "rule " <> quote(rule.name))],
    render_tags(2, rule.tags),
    render_description(2, rule.description),
    render_background(2, rule.background),
    list.flat_map(rule.scenarios, render_scenario(2, _)),
  ])
}

fn render_background(
  depth: Int,
  background: Option(gherkin_types.Background),
) -> List(String) {
  case background {
    None -> []
    Some(background) ->
      list.flatten([
        [line(depth, "background " <> quote(background.name))],
        render_description(depth + 1, background.description),
        list.flat_map(background.steps, render_step(depth + 1, _)),
      ])
  }
}

fn render_scenario(
  depth: Int,
  scenario: gherkin_types.Scenario,
) -> List(String) {
  list.flatten([
    [
      line(
        depth,
        "scenario "
          <> quote(gherkin_types.scenario_keyword_to_string(scenario.keyword))
          <> " "
          <> quote(scenario.name),
      ),
    ],
    render_tags(depth + 1, scenario.tags),
    render_description(depth + 1, scenario.description),
    list.flat_map(scenario.steps, render_step(depth + 1, _)),
    list.flat_map(scenario.examples, render_examples(depth + 1, _)),
  ])
}

fn render_examples(
  depth: Int,
  examples: gherkin_types.Examples,
) -> List(String) {
  list.flatten([
    [line(depth, "examples " <> quote(examples.name))],
    render_tags(depth + 1, examples.tags),
    render_description(depth + 1, examples.description),
    render_examples_table(depth + 1, examples.table),
  ])
}

fn render_examples_table(
  depth: Int,
  table: Option(gherkin_types.ExamplesTable),
) -> List(String) {
  case table {
    None -> []
    Some(table) -> [
      render_row(depth, "header", table.headers),
      ..list.map(table.rows, render_row(depth, "row", _))
    ]
  }
}

fn render_step(depth: Int, step: gherkin_types.Step) -> List(String) {
  [
    line(
      depth,
      "step "
        <> quote(gherkin_types.keyword_to_string(step.keyword))
        <> " "
        <> quote(step.text),
    ),
    ..render_argument(depth + 1, step.argument)
  ]
}

fn render_argument(
  depth: Int,
  argument: Option(gherkin_types.StepArgument),
) -> List(String) {
  case argument {
    None -> []
    Some(gherkin_types.DocString(content, None)) -> [
      line(depth, "docstring none " <> quote(content)),
    ]
    Some(gherkin_types.DocString(content, Some(media_type))) -> [
      line(depth, "docstring " <> quote(media_type) <> " " <> quote(content)),
    ]
    Some(gherkin_types.DataTable(rows)) -> [
      line(depth, "table"),
      ..list.map(rows, render_row(depth + 1, "row", _))
    ]
  }
}

fn render_row(depth: Int, label: String, cells: List(String)) -> String {
  line(depth, label <> " " <> string.join(list.map(cells, quote), " "))
}

fn render_tags(depth: Int, tags: List(String)) -> List(String) {
  case tags {
    [] -> []
    _ -> [line(depth, "tags " <> string.join(list.map(tags, quote), " "))]
  }
}

fn render_description(depth: Int, description: Option(String)) -> List(String) {
  case description {
    None -> []
    Some(text) -> [line(depth, "description " <> quote(text))]
  }
}

fn line(depth: Int, text: String) -> String {
  string.repeat("  ", depth) <> text
}

fn quote(text: String) -> String {
  let escaped =
    text
    |> string.replace("\\", "\\\\")
    |> string.replace("\"", "\\\"")
    |> string.replace("\n", "\\n")
  "\"" <> escaped <> "\""
}
