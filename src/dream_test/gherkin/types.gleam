//// Gherkin types for dream_test.
////
//// These are the data structures produced by the Gherkin parser and consumed
//// by the feature/discovery APIs. Most users won’t construct them directly,
//// but they’re useful when you’re integrating your own parser or tooling.
////
//// ## Example
////
//// Use this when building BDD suites (e.g. in a snippet `tests()` function).
////
//// ```gleam
//// keyword_to_string(Given)
//// |> should
//// |> be_equal("Given")
//// |> or_fail_with("expected Given")
//// ```

import gleam/option.{type Option}

// ============================================================================
// Step Types
// ============================================================================

/// Keywords that can start a step.
///
/// In Gherkin, each step begins with one of these keywords:
/// - `Given` - Describes initial context/preconditions
/// - `When` - Describes an action
/// - `Then` - Describes an expected outcome
/// - `And` / `But` - Continues the previous step
/// - `Asterisk` - The `*` keyword, which also continues the previous step
///
/// When matching step definitions, `And`, `But` and `*` take the phase of the
/// step before them (e.g., `And` after `Given` is matched as a Given step).
/// See `StepPhase` and `resolve_phase`.
///
pub type StepKeyword {
  Given
  When
  Then
  And
  But
  /// The `*` keyword. It takes the phase of the step before it.
  Asterisk
}

/// The phase of a step: the part of a scenario that the step belongs to.
///
/// Given, When and Then map to Arrange, Act and Assert. Every step definition
/// belongs to exactly one phase, and a step matches only the definitions of
/// its phase. `And`, `But` and `*` steps have no phase of their own: they take
/// the phase of the step before them (see `resolve_phase`).
///
/// ## Example
///
/// ```gleam
/// resolve_phase(keyword: And, previous: Some(GivenPhase))
/// |> should
/// |> be_equal(Ok(GivenPhase))
/// |> or_fail_with("expected And after Given to be a Given step")
/// ```
///
pub type StepPhase {
  /// Arrange: the context before the action (`Given` steps).
  GivenPhase
  /// Act: the action (`When` steps).
  WhenPhase
  /// Assert: the expected outcome (`Then` steps).
  ThenPhase
}

/// Multi-line text after a step, between two `"""` (or two `` ``` ``) lines.
///
/// - `content` - The text between the separators
/// - `content_type` - The media type after the opening separator, if any
///   (for example `json` in `"""json`)
///
/// ## Example
///
/// ```gleam
/// DocString(content: "{\"name\":\"example\"}", content_type: Some("json"))
/// |> should
/// |> be_equal(DocString(
///   content: "{\"name\":\"example\"}",
///   content_type: Some("json"),
/// ))
/// |> or_fail_with("expected DocString to be constructible")
/// ```
///
pub type DocString {
  DocString(content: String, content_type: Option(String))
}

/// Table rows after a step, one `| cell | cell |` line for each row.
///
/// Each row is a list of cell values. The first row is usually the headers.
///
/// ## Example
///
/// ```gleam
/// DataTable(rows: [["name", "email"], ["Alice", "alice@test.com"]])
/// |> should
/// |> be_equal(
///   DataTable(rows: [["name", "email"], ["Alice", "alice@test.com"]]),
/// )
/// |> or_fail_with("expected DataTable to be constructible")
/// ```
///
pub type DataTable {
  DataTable(rows: List(List(String)))
}

/// A single step in a scenario.
///
/// Steps are the executable units of a scenario. Each step has:
/// - A keyword (Given/When/Then/And/But/*)
/// - Text describing the action
/// - An optional DocString
/// - An optional DataTable
///
/// A step can have both a DocString and a DataTable, in either order, as
/// in the official Gherkin grammar. A step handler gets them as
/// `StepContext.doc_string` and `StepContext.table`.
///
/// ## Example
///
/// ```gleam
/// Step(
///   keyword: Given,
///   text: "I have 1 item",
///   doc_string: None,
///   data_table: None,
/// )
/// |> should
/// |> be_equal(Step(
///   keyword: Given,
///   text: "I have 1 item",
///   doc_string: None,
///   data_table: None,
/// ))
/// |> or_fail_with("expected Step to be constructible")
/// ```
///
pub type Step {
  Step(
    /// The step keyword (Given, When, Then, And, But, *)
    keyword: StepKeyword,
    /// The step text after the keyword
    text: String,
    /// The DocString after the step, if any
    doc_string: Option(DocString),
    /// The DataTable after the step, if any
    data_table: Option(DataTable),
  )
}

// ============================================================================
// Background
// ============================================================================

/// Steps that run before each scenario of a Feature or a Rule.
///
/// A Feature can have one Background. Each Rule can also have one
/// Background. The steps of a Feature Background run before the steps of a
/// Rule Background, and both run before the steps of the scenario.
///
/// ## Example
///
/// ```gleam
/// empty_background()
/// |> should
/// |> be_equal(Background(name: "", description: None, steps: []))
/// |> or_fail_with("expected empty background")
/// ```
///
pub type Background {
  Background(
    /// The text after `Background:`. It is `""` when the line has no name.
    name: String,
    /// The free text below the `Background:` line, if there is some.
    description: Option(String),
    /// The steps, in file order.
    steps: List(Step),
  )
}

// ============================================================================
// Examples (for Scenario Outline)
// ============================================================================

/// The table of an `Examples:` section.
///
/// The first row of the table is the header row. Each other row makes one
/// scenario, with each `<placeholder>` replaced by the value in its column.
///
/// ## Example
///
/// ```gleam
/// ExamplesTable(headers: ["quantity"], rows: [["1"], ["5"]])
/// |> should
/// |> be_equal(ExamplesTable(headers: ["quantity"], rows: [["1"], ["5"]]))
/// |> or_fail_with("expected ExamplesTable to be constructible")
/// ```
pub type ExamplesTable {
  ExamplesTable(
    /// Column headers (e.g., ["quantity", "product"])
    headers: List(String),
    /// Data rows, each containing values for all columns
    rows: List(List(String)),
  )
}

/// One `Examples:` (or `Scenarios:`) section of a scenario.
///
/// A scenario can have more than one `Examples` section. Every row of every
/// section runs. The tags of an `Examples` section apply to the scenarios
/// that its rows make.
///
/// ## Example
///
/// ```gleam
/// let table = ExamplesTable(headers: ["quantity"], rows: [["1"]])
///
/// Examples(name: "Small", description: None, tags: ["fast"], table: Some(table))
/// |> should
/// |> be_equal(Examples(
///   name: "Small",
///   description: None,
///   tags: ["fast"],
///   table: Some(table),
/// ))
/// |> or_fail_with("expected Examples to be constructible")
/// ```
///
pub type Examples {
  Examples(
    /// The text after `Examples:`. It is `""` when the line has no name.
    name: String,
    /// The free text below the `Examples:` line, if there is some.
    description: Option(String),
    /// The tags on the lines above the `Examples:` line, without the `@`.
    tags: List(String),
    /// The table, or `None` when the section has no table rows.
    table: Option(ExamplesTable),
  )
}

// ============================================================================
// Scenario Types
// ============================================================================

/// The keyword that starts a scenario.
///
/// Gherkin has two synonyms for a scenario and two synonyms for a scenario
/// outline. The keyword does not change how the scenario runs: a scenario
/// with `Examples` runs one time for each example row, and a scenario without
/// `Examples` runs one time.
///
/// ## Example
///
/// ```gleam
/// scenario_keyword_to_string(KeywordScenarioOutline)
/// |> should
/// |> be_equal("Scenario Outline")
/// |> or_fail_with("expected Scenario Outline")
/// ```
///
pub type ScenarioKeyword {
  /// `Scenario:`
  KeywordScenario
  /// `Example:`, a synonym for `Scenario:`
  KeywordExample
  /// `Scenario Outline:`
  KeywordScenarioOutline
  /// `Scenario Template:`, a synonym for `Scenario Outline:`
  KeywordScenarioTemplate
}

/// A scenario within a Feature or a Rule.
///
/// A scenario with no `examples` runs one time. A scenario with `examples`
/// runs one time for each row of each `Examples` table, with each
/// `<placeholder>` in the step text replaced by the value in its column.
///
/// ## Example
///
/// ```gleam
/// let step =
///   Step(
///     keyword: Given,
///     text: "I have 1 item",
///     doc_string: None,
///     data_table: None,
///   )
/// let scenario =
///   Scenario(
///     keyword: KeywordScenario,
///     name: "Example scenario",
///     description: None,
///     tags: [],
///     steps: [step],
///     examples: [],
///   )
///
/// scenario.name
/// |> should
/// |> be_equal("Example scenario")
/// |> or_fail_with("expected Scenario to be constructible")
/// ```
///
pub type Scenario {
  Scenario(
    /// The keyword that started the scenario
    keyword: ScenarioKeyword,
    /// The scenario name
    name: String,
    /// The free text below the scenario line, if there is some.
    description: Option(String),
    /// Tags applied to this scenario (e.g., @slow, @wip), without the `@`
    tags: List(String),
    /// The steps to execute. Outline steps use `<placeholder>` text.
    steps: List(Step),
    /// The `Examples` sections, in file order
    examples: List(Examples),
  )
}

// ============================================================================
// Rule
// ============================================================================

/// A `Rule:` section of a Feature.
///
/// A Rule groups scenarios that show one business rule. A Rule can have its
/// own Background. Its steps run after the steps of the Feature Background.
///
/// ## Example
///
/// ```gleam
/// Rule(name: "Stock", description: None, tags: [], background: None, scenarios: [])
/// |> should
/// |> be_equal(Rule(
///   name: "Stock",
///   description: None,
///   tags: [],
///   background: None,
///   scenarios: [],
/// ))
/// |> or_fail_with("expected Rule to be constructible")
/// ```
///
pub type Rule {
  Rule(
    /// The text after `Rule:`. It is `""` when the line has no name.
    name: String,
    /// The free text below the `Rule:` line, if there is some.
    description: Option(String),
    /// The tags on the lines above the `Rule:` line, without the `@`.
    tags: List(String),
    /// The Background of this Rule, if it has one
    background: Option(Background),
    /// The scenarios of this Rule, in file order
    scenarios: List(Scenario),
  )
}

// ============================================================================
// Feature
// ============================================================================

/// A parsed Gherkin feature file.
///
/// A feature represents a complete `.feature` file containing:
/// - Metadata (name, description, tags)
/// - An optional Background
/// - Scenarios that are not in a Rule
/// - Rules, each with an optional Background and its own scenarios
///
/// Gherkin puts these in a fixed order: the Background first, then the
/// scenarios, then the Rules. The fields keep that order.
///
/// ## Example
///
/// ```gleam
/// let step =
///   Step(
///     keyword: Given,
///     text: "I have 1 item",
///     doc_string: None,
///     data_table: None,
///   )
/// let scenario =
///   Scenario(
///     keyword: KeywordScenario,
///     name: "Example scenario",
///     description: None,
///     tags: [],
///     steps: [step],
///     examples: [],
///   )
///
/// let feature =
///   Feature(
///     name: "Example feature",
///     source: None,
///     description: None,
///     tags: [],
///     background: None,
///     scenarios: [scenario],
///     rules: [],
///   )
///
/// feature.name
/// |> should
/// |> be_equal("Example feature")
/// |> or_fail_with("expected Feature to be constructible")
/// ```
///
pub type Feature {
  Feature(
    /// The feature name (from the Feature: line)
    name: String,
    /// Optional source identifier (typically the .feature file path)
    source: Option(String),
    /// Optional description text below the feature name. Each line keeps
    /// its leading whitespace, as in the file.
    description: Option(String),
    /// Tags applied to the feature (inherited by all scenarios)
    tags: List(String),
    /// Optional background steps run before each scenario
    background: Option(Background),
    /// The scenarios that are not in a Rule
    scenarios: List(Scenario),
    /// The Rules, in file order
    rules: List(Rule),
  )
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Convert a ScenarioKeyword to the keyword text used in a `.feature` file.
///
/// ## Example
///
/// ```gleam
/// scenario_keyword_to_string(KeywordExample)
/// |> should
/// |> be_equal("Example")
/// |> or_fail_with("expected Example")
/// ```
///
pub fn scenario_keyword_to_string(keyword keyword: ScenarioKeyword) -> String {
  case keyword {
    KeywordScenario -> "Scenario"
    KeywordExample -> "Example"
    KeywordScenarioOutline -> "Scenario Outline"
    KeywordScenarioTemplate -> "Scenario Template"
  }
}

/// Convert a StepKeyword to its string representation.
///
/// ## Example
///
/// ```gleam
/// keyword_to_string(Given)
/// |> should
/// |> be_equal("Given")
/// |> or_fail_with("expected Given")
/// ```
///
pub fn keyword_to_string(keyword keyword: StepKeyword) -> String {
  case keyword {
    Given -> "Given"
    When -> "When"
    Then -> "Then"
    And -> "And"
    But -> "But"
    Asterisk -> "*"
  }
}

/// Parse a string to a StepKeyword.
///
/// Returns the keyword if recognized, or None for unknown strings.
///
/// ## Example
///
/// ```gleam
/// keyword_from_string("Then")
/// |> should
/// |> be_equal(Some(Then))
/// |> or_fail_with("expected Some(Then)")
/// ```
///
pub fn keyword_from_string(text text: String) -> Option(StepKeyword) {
  case text {
    "Given" -> option.Some(Given)
    "When" -> option.Some(When)
    "Then" -> option.Some(Then)
    "And" -> option.Some(And)
    "But" -> option.Some(But)
    "*" -> option.Some(Asterisk)
    _ -> option.None
  }
}

/// Find the phase of a step from its keyword and the phase of the step
/// before it.
///
/// `Given`, `When` and `Then` give their own phase. `And`, `But` and `*` give
/// the phase of the step before them, so they need a previous phase. With no
/// previous phase (`None`), they give `Error(Nil)`: a scenario cannot start
/// with `And`, `But` or `*` unless a Background step comes before it.
///
/// ## Example
///
/// ```gleam
/// resolve_phase(keyword: And, previous: Some(GivenPhase))
/// |> should
/// |> be_equal(Ok(GivenPhase))
/// |> or_fail_with("expected And after Given to be a Given step")
/// ```
///
pub fn resolve_phase(
  keyword keyword: StepKeyword,
  previous previous: Option(StepPhase),
) -> Result(StepPhase, Nil) {
  case keyword {
    Given -> Ok(GivenPhase)
    When -> Ok(WhenPhase)
    Then -> Ok(ThenPhase)
    And -> option.to_result(previous, Nil)
    But -> option.to_result(previous, Nil)
    Asterisk -> option.to_result(previous, Nil)
  }
}

/// Convert a StepPhase to the name of its keyword.
///
/// ## Example
///
/// ```gleam
/// phase_to_string(WhenPhase)
/// |> should
/// |> be_equal("When")
/// |> or_fail_with("expected When")
/// ```
///
pub fn phase_to_string(phase phase: StepPhase) -> String {
  case phase {
    GivenPhase -> "Given"
    WhenPhase -> "When"
    ThenPhase -> "Then"
  }
}

/// Create an empty examples table.
///
/// Useful as a default value or for testing.
///
/// ## Example
///
/// ```gleam
/// empty_examples()
/// |> should
/// |> be_equal(ExamplesTable(headers: [], rows: []))
/// |> or_fail_with("expected empty examples table")
/// ```
///
pub fn empty_examples() -> ExamplesTable {
  ExamplesTable(headers: [], rows: [])
}

/// Create an empty background.
///
/// Useful as a default value or for testing.
///
/// ## Example
///
/// ```gleam
/// empty_background()
/// |> should
/// |> be_equal(Background(name: "", description: None, steps: []))
/// |> or_fail_with("expected empty background")
/// ```
///
pub fn empty_background() -> Background {
  Background(name: "", description: option.None, steps: [])
}
