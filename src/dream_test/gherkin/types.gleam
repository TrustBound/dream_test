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
/// - `And` / `But` - Continues the previous step type
///
/// When matching step definitions, `And` and `But` inherit the keyword
/// type from the previous step (e.g., `And` after `Given` is treated as `Given`).
///
pub type StepKeyword {
  Given
  When
  Then
  And
  But
}

/// Optional argument attached to a step.
///
/// Steps can have additional structured data:
///
/// ## DocString
///
/// Multi-line text enclosed in triple quotes:
///
/// In Dream Test these values are represented as `DocString(...)`.
///
/// ## DataTable
///
/// Tabular data with pipe-delimited rows:
///
/// In Dream Test these values are represented as `DataTable(...)`.
///
pub type StepArgument {
  /// Multi-line text content.
  /// - `content` - The text between the triple quotes
  /// - `content_type` - Optional media type hint (e.g., "json", "xml")
  DocString(content: String, content_type: Option(String))

  /// Tabular data as a list of rows.
  /// Each row is a list of cell values.
  /// The first row is typically headers.
  DataTable(rows: List(List(String)))
}

/// A single step in a scenario.
///
/// Steps are the executable units of a scenario. Each step has:
/// - A keyword (Given/When/Then/And/But)
/// - Text describing the action
/// - Optional argument (DocString or DataTable)
///
/// ## Example
///
/// ```gleam
/// Step(keyword: Given, text: "I have 1 item", argument: None)
/// |> should
/// |> be_equal(Step(keyword: Given, text: "I have 1 item", argument: None))
/// |> or_fail_with("expected Step to be constructible")
/// ```
///
pub type Step {
  Step(
    /// The step keyword (Given, When, Then, And, But)
    keyword: StepKeyword,
    /// The step text after the keyword
    text: String,
    /// Optional DocString or DataTable argument
    argument: Option(StepArgument),
  )
}

// ============================================================================
// Background
// ============================================================================

/// Background steps that run before each scenario.
///
/// A Background defines common setup steps that are executed before
/// every scenario in the feature. It's useful for shared preconditions.
///
/// Background steps run before each scenario, as if they were prepended.
///
/// ## Example
///
/// ```gleam
/// empty_background()
/// |> should
/// |> be_equal(Background(steps: []))
/// |> or_fail_with("expected empty background")
/// ```
///
pub type Background {
  Background(steps: List(Step))
}

// ============================================================================
// Examples Table (for Scenario Outline)
// ============================================================================

/// Examples table for Scenario Outline.
///
/// Provides data for parameterized scenarios. Each row generates a
/// separate scenario instance with placeholders replaced by values.
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

// ============================================================================
// Scenario Types
// ============================================================================

/// A scenario within a feature.
///
/// There are two variants:
///
/// A `Scenario` has concrete step text; a `ScenarioOutline` is parameterized
/// with an examples table and uses `<placeholder>` values in step text.
///
/// ## Example
///
/// ```gleam
/// let step = Step(keyword: Given, text: "I have 1 item", argument: None)
///
/// Scenario(name: "Example scenario", tags: [], steps: [step])
/// |> should
/// |> be_equal(Scenario(name: "Example scenario", tags: [], steps: [step]))
/// |> or_fail_with("expected Scenario to be constructible")
/// ```
///
pub type Scenario {
  /// A standard scenario with fixed step values.
  Scenario(
    /// The scenario name
    name: String,
    /// Tags applied to this scenario (e.g., @slow, @wip)
    tags: List(String),
    /// The steps to execute
    steps: List(Step),
  )

  /// A parameterized scenario expanded from examples.
  ScenarioOutline(
    /// The scenario outline name
    name: String,
    /// Tags applied to this scenario outline
    tags: List(String),
    /// The step templates with <placeholder> syntax
    steps: List(Step),
    /// The examples table for parameterization
    examples: ExamplesTable,
  )
}

// ============================================================================
// Feature
// ============================================================================

/// A parsed Gherkin feature file.
///
/// A feature represents a complete `.feature` file containing:
/// - Metadata (name, description, tags)
/// - Optional background steps
/// - One or more scenarios
///
/// ## Example
///
/// ```gleam
/// let step = Step(keyword: Given, text: "I have 1 item", argument: None)
/// let scenario = Scenario(name: "Example scenario", tags: [], steps: [step])
///
/// Feature(
///   name: "Example feature",
///   description: None,
///   tags: [],
///   background: None,
///   scenarios: [scenario],
/// )
/// |> should
/// |> be_equal(
///   Feature(
///     name: "Example feature",
///     description: None,
///     tags: [],
///     background: None,
///     scenarios: [scenario],
///   ),
/// )
/// |> or_fail_with("expected Feature to be constructible")
/// ```
///
pub type Feature {
  Feature(
    /// The feature name (from the Feature: line)
    name: String,
    /// Optional source identifier (typically the .feature file path)
    source: Option(String),
    /// Optional description text below the feature name
    description: Option(String),
    /// Tags applied to the feature (inherited by all scenarios)
    tags: List(String),
    /// Optional background steps run before each scenario
    background: Option(Background),
    /// The scenarios in this feature
    scenarios: List(Scenario),
  )
}

// ============================================================================
// Helper Functions
// ============================================================================

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
    _ -> option.None
  }
}

/// Resolve And/But to the effective keyword based on previous step.
///
/// In Gherkin, `And` and `But` inherit meaning from the previous step.
/// This function resolves them to their effective keyword type.
///
/// ## Example
///
/// ```gleam
/// resolve_keyword(And, Given)
/// |> should
/// |> be_equal(Given)
/// |> or_fail_with("expected And after Given to resolve to Given")
/// ```
///
pub fn resolve_keyword(
  keyword keyword: StepKeyword,
  previous previous: StepKeyword,
) -> StepKeyword {
  case keyword {
    And -> previous
    But -> previous
    other -> other
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
/// |> be_equal(Background(steps: []))
/// |> or_fail_with("expected empty background")
/// ```
///
pub fn empty_background() -> Background {
  Background(steps: [])
}
