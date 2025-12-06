//// Gherkin parser for `.feature` files.
////
//// Parses Gherkin syntax into structured Feature types that can be
//// converted to dream_test TestSuites.
////
//// ## Supported Syntax
////
//// - Feature, Scenario, Scenario Outline
//// - Background
//// - Given/When/Then/And/But steps
//// - Tags (@tag syntax)
//// - DataTables (pipe-delimited)
//// - DocStrings (triple quotes)
//// - Examples tables for Scenario Outlines
//// - Comments (# lines)
////
//// ## Example Usage
////
//// ```gleam
//// import dream_test/gherkin/parser
////
//// // Parse from file
//// case parser.parse_file("test/features/shopping.feature") {
////   Ok(feature) -> run_feature(feature)
////   Error(msg) -> panic as msg
//// }
////
//// // Parse from string
//// let content = "Feature: My Feature\n  Scenario: Test\n    Given something"
//// case parser.parse_string(content) {
////   Ok(feature) -> run_feature(feature)
////   Error(msg) -> panic as msg
//// }
//// ```

import dream_test/file
import dream_test/gherkin/types.{
  type Background, type ExamplesTable, type Feature, type Scenario, type Step,
  type StepKeyword, And, Background, But, DataTable, DocString, ExamplesTable,
  Feature, Given, Scenario, ScenarioOutline, Step, Then, When,
}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// ============================================================================
// Public API
// ============================================================================

/// Parse a `.feature` file from disk.
///
/// Reads the file and parses its contents into a Feature.
///
/// ## Parameters
///
/// - `path`: Path to the `.feature` file
///
/// ## Returns
///
/// - `Ok(Feature)`: Successfully parsed feature
/// - `Error(String)`: Parse error with description
///
pub fn parse_file(path: String) -> Result(Feature, String) {
  case file.read(path) {
    Ok(content) -> parse_string(content)
    Error(error) ->
      Error("Failed to read feature file: " <> file.error_to_string(error))
  }
}

/// Parse Gherkin content from a string.
///
/// Parses the provided string as Gherkin syntax.
///
/// ## Parameters
///
/// - `content`: Gherkin content as a string
///
/// ## Returns
///
/// - `Ok(Feature)`: Successfully parsed feature
/// - `Error(String)`: Parse error with description
///
pub fn parse_string(content: String) -> Result(Feature, String) {
  let lines = string.split(content, "\n")
  let state = initial_state()
  parse_lines(lines, state)
}

// ============================================================================
// Parser State
// ============================================================================

type ParserState {
  ParserState(
    feature_name: Option(String),
    feature_description: Option(String),
    feature_tags: List(String),
    background: Option(Background),
    scenarios: List(Scenario),
    current_scenario_name: Option(String),
    current_scenario_tags: List(String),
    current_steps: List(Step),
    current_examples: Option(ExamplesTable),
    pending_tags: List(String),
    in_doc_string: Bool,
    doc_string_content: List(String),
    doc_string_type: Option(String),
    in_background: Bool,
    in_scenario_outline: Bool,
  )
}

fn initial_state() -> ParserState {
  ParserState(
    feature_name: None,
    feature_description: None,
    feature_tags: [],
    background: None,
    scenarios: [],
    current_scenario_name: None,
    current_scenario_tags: [],
    current_steps: [],
    current_examples: None,
    pending_tags: [],
    in_doc_string: False,
    doc_string_content: [],
    doc_string_type: None,
    in_background: False,
    in_scenario_outline: False,
  )
}

// ============================================================================
// Line-by-Line Parser
// ============================================================================

fn parse_lines(
  lines: List(String),
  state: ParserState,
) -> Result(Feature, String) {
  case lines {
    [] -> finalize_feature(state)
    [line, ..rest] -> {
      case parse_line(line, state) {
        Ok(new_state) -> parse_lines(rest, new_state)
        Error(msg) -> Error(msg)
      }
    }
  }
}

fn parse_line(line: String, state: ParserState) -> Result(ParserState, String) {
  let trimmed = string.trim(line)

  // Handle doc string mode
  case state.in_doc_string {
    True -> handle_doc_string_line(trimmed, line, state)
    False -> handle_normal_line(trimmed, state)
  }
}

fn handle_doc_string_line(
  trimmed: String,
  original: String,
  state: ParserState,
) -> Result(ParserState, String) {
  case string.starts_with(trimmed, "\"\"\"") {
    True -> close_doc_string(state)
    False -> append_doc_string_line(original, state)
  }
}

fn close_doc_string(state: ParserState) -> Result(ParserState, String) {
  let content = string.join(list.reverse(state.doc_string_content), "\n")
  let doc_string =
    DocString(content: content, content_type: state.doc_string_type)

  // Attach to the last step
  case list.reverse(state.current_steps) {
    [Step(keyword, text, _), ..rest] -> {
      let updated_step = Step(keyword, text, Some(doc_string))
      let new_steps = list.reverse([updated_step, ..rest])
      Ok(
        ParserState(
          ..state,
          current_steps: new_steps,
          in_doc_string: False,
          doc_string_content: [],
          doc_string_type: None,
        ),
      )
    }
    [] -> Error("DocString without preceding step")
  }
}

fn append_doc_string_line(
  line: String,
  state: ParserState,
) -> Result(ParserState, String) {
  Ok(
    ParserState(..state, doc_string_content: [line, ..state.doc_string_content]),
  )
}

fn handle_normal_line(
  trimmed: String,
  state: ParserState,
) -> Result(ParserState, String) {
  case trimmed {
    // Empty line or comment
    "" -> Ok(state)
    "#" <> _ -> Ok(state)

    // Tags
    "@" <> _ -> parse_tags(trimmed, state)

    // Feature
    "Feature:" <> rest -> parse_feature_line(rest, state)

    // Background
    "Background:" -> start_background(state)

    // Scenario
    "Scenario:" <> rest -> start_scenario(rest, state)

    // Scenario Outline
    "Scenario Outline:" <> rest -> start_scenario_outline(rest, state)

    // Examples
    "Examples:" -> start_examples(state)

    // Steps
    "Given " <> rest -> parse_step(Given, rest, state)
    "When " <> rest -> parse_step(When, rest, state)
    "Then " <> rest -> parse_step(Then, rest, state)
    "And " <> rest -> parse_step(And, rest, state)
    "But " <> rest -> parse_step(But, rest, state)

    // DocString start
    "\"\"\"" <> type_hint -> start_doc_string(type_hint, state)

    // DataTable row
    "|" <> _ -> parse_table_row(trimmed, state)

    // Unknown line (could be description)
    _ -> parse_description_or_unknown(trimmed, state)
  }
}

// ============================================================================
// Tag Parsing
// ============================================================================

fn parse_tags(line: String, state: ParserState) -> Result(ParserState, String) {
  let tags = extract_tags(line)
  Ok(ParserState(..state, pending_tags: list.append(state.pending_tags, tags)))
}

fn extract_tags(line: String) -> List(String) {
  line
  |> string.split(" ")
  |> list.filter(is_tag)
  |> list.map(extract_tag_name)
}

fn is_tag(word: String) -> Bool {
  string.starts_with(word, "@")
}

fn extract_tag_name(tag: String) -> String {
  string.drop_start(tag, 1)
}

// ============================================================================
// Feature Parsing
// ============================================================================

fn parse_feature_line(
  name: String,
  state: ParserState,
) -> Result(ParserState, String) {
  Ok(
    ParserState(
      ..state,
      feature_name: Some(string.trim(name)),
      feature_tags: state.pending_tags,
      pending_tags: [],
    ),
  )
}

// ============================================================================
// Background Parsing
// ============================================================================

fn start_background(state: ParserState) -> Result(ParserState, String) {
  Ok(ParserState(..state, in_background: True, current_steps: []))
}

// ============================================================================
// Scenario Parsing
// ============================================================================

fn start_scenario(
  name: String,
  state: ParserState,
) -> Result(ParserState, String) {
  // Finalize any previous scenario
  let state_with_previous = finalize_current_scenario(state)

  Ok(
    ParserState(
      ..state_with_previous,
      current_scenario_name: Some(string.trim(name)),
      current_scenario_tags: state_with_previous.pending_tags,
      current_steps: [],
      current_examples: None,
      pending_tags: [],
      in_background: False,
      in_scenario_outline: False,
    ),
  )
}

fn start_scenario_outline(
  name: String,
  state: ParserState,
) -> Result(ParserState, String) {
  // Finalize any previous scenario
  let state_with_previous = finalize_current_scenario(state)

  Ok(
    ParserState(
      ..state_with_previous,
      current_scenario_name: Some(string.trim(name)),
      current_scenario_tags: state_with_previous.pending_tags,
      current_steps: [],
      current_examples: None,
      pending_tags: [],
      in_background: False,
      in_scenario_outline: True,
    ),
  )
}

fn finalize_current_scenario(state: ParserState) -> ParserState {
  case state.in_background {
    True -> finalize_background(state)
    False -> finalize_scenario(state)
  }
}

fn finalize_background(state: ParserState) -> ParserState {
  case state.current_steps {
    [] -> state
    steps -> {
      let background = Background(steps: list.reverse(steps))
      ParserState(
        ..state,
        background: Some(background),
        current_steps: [],
        in_background: False,
      )
    }
  }
}

fn finalize_scenario(state: ParserState) -> ParserState {
  case state.current_scenario_name {
    None -> state
    Some(name) -> {
      let steps = list.reverse(state.current_steps)
      let scenario =
        build_scenario(
          name,
          state.current_scenario_tags,
          steps,
          state.current_examples,
          state.in_scenario_outline,
        )
      ParserState(
        ..state,
        scenarios: [scenario, ..state.scenarios],
        current_scenario_name: None,
        current_scenario_tags: [],
        current_steps: [],
        current_examples: None,
        in_scenario_outline: False,
      )
    }
  }
}

fn build_scenario(
  name: String,
  tags: List(String),
  steps: List(Step),
  examples: Option(ExamplesTable),
  is_outline: Bool,
) -> Scenario {
  case is_outline, examples {
    True, Some(ex) ->
      ScenarioOutline(name: name, tags: tags, steps: steps, examples: ex)
    True, None ->
      ScenarioOutline(
        name: name,
        tags: tags,
        steps: steps,
        examples: types.empty_examples(),
      )
    False, _ -> Scenario(name: name, tags: tags, steps: steps)
  }
}

// ============================================================================
// Step Parsing
// ============================================================================

fn parse_step(
  keyword: StepKeyword,
  text: String,
  state: ParserState,
) -> Result(ParserState, String) {
  let step = Step(keyword: keyword, text: string.trim(text), argument: None)
  Ok(ParserState(..state, current_steps: [step, ..state.current_steps]))
}

// ============================================================================
// DocString Parsing
// ============================================================================

fn start_doc_string(
  type_hint: String,
  state: ParserState,
) -> Result(ParserState, String) {
  let content_type = case string.trim(type_hint) {
    "" -> None
    t -> Some(t)
  }
  Ok(
    ParserState(
      ..state,
      in_doc_string: True,
      doc_string_content: [],
      doc_string_type: content_type,
    ),
  )
}

// ============================================================================
// DataTable Parsing
// ============================================================================

fn parse_table_row(
  line: String,
  state: ParserState,
) -> Result(ParserState, String) {
  let cells = parse_table_cells(line)

  // Check if this is an Examples table or a step DataTable
  case state.current_examples {
    Some(ex) -> add_examples_row(cells, ex, state)
    None -> add_data_table_row(cells, state)
  }
}

fn parse_table_cells(line: String) -> List(String) {
  line
  |> string.split("|")
  |> list.filter(is_non_empty_cell)
  |> list.map(string.trim)
}

fn is_non_empty_cell(cell: String) -> Bool {
  string.trim(cell) != ""
}

fn add_examples_row(
  cells: List(String),
  examples: ExamplesTable,
  state: ParserState,
) -> Result(ParserState, String) {
  let updated = case examples.headers {
    [] -> ExamplesTable(headers: cells, rows: [])
    _ ->
      ExamplesTable(
        headers: examples.headers,
        rows: list.append(examples.rows, [cells]),
      )
  }
  Ok(ParserState(..state, current_examples: Some(updated)))
}

fn add_data_table_row(
  cells: List(String),
  state: ParserState,
) -> Result(ParserState, String) {
  // Add to the last step's DataTable
  case list.reverse(state.current_steps) {
    [Step(keyword, text, arg), ..rest] -> {
      let updated_arg = case arg {
        Some(DataTable(rows)) -> DataTable(rows: list.append(rows, [cells]))
        Some(other) -> other
        None -> DataTable(rows: [cells])
      }
      let updated_step = Step(keyword, text, Some(updated_arg))
      let new_steps = list.reverse([updated_step, ..rest])
      Ok(ParserState(..state, current_steps: new_steps))
    }
    [] -> Error("DataTable without preceding step")
  }
}

// ============================================================================
// Examples Section
// ============================================================================

fn start_examples(state: ParserState) -> Result(ParserState, String) {
  Ok(ParserState(..state, current_examples: Some(types.empty_examples())))
}

// ============================================================================
// Description Parsing
// ============================================================================

fn parse_description_or_unknown(
  line: String,
  state: ParserState,
) -> Result(ParserState, String) {
  // If we have a feature but no scenario yet, this is description
  case state.feature_name, state.current_scenario_name {
    Some(_), None -> {
      let description = case state.feature_description {
        None -> line
        Some(existing) -> existing <> "\n" <> line
      }
      Ok(ParserState(..state, feature_description: Some(description)))
    }
    _, _ -> Ok(state)
    // Ignore unknown lines
  }
}

// ============================================================================
// Finalization
// ============================================================================

fn finalize_feature(state: ParserState) -> Result(Feature, String) {
  let final_state = finalize_current_scenario(state)

  case final_state.feature_name {
    None -> Error("No Feature found in content")
    Some(name) ->
      Ok(Feature(
        name: name,
        description: final_state.feature_description,
        tags: final_state.feature_tags,
        background: final_state.background,
        scenarios: list.reverse(final_state.scenarios),
      ))
  }
}
