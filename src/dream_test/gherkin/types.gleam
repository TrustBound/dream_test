//// Gherkin types for dream_test.
////
//// This module defines the data structures representing parsed Gherkin
//// `.feature` files. These types are used by the parser and converted
//// to dream_test's `TestCase` and `TestSuite` types for execution.
////
//// ## Type Overview
////
//// | Type              | Purpose                                          |
//// |-------------------|--------------------------------------------------|
//// | `Feature`         | A parsed `.feature` file                         |
//// | `Scenario`        | A single scenario or scenario outline            |
//// | `Step`            | A Given/When/Then step with text                 |
//// | `StepKeyword`     | The keyword type (Given, When, Then, And, But)   |
//// | `StepArgument`    | Optional DocString or DataTable                  |
//// | `Background`      | Steps to run before each scenario                |
//// | `ExamplesTable`   | Data table for Scenario Outline expansion        |
////
//// ## Gherkin Syntax Reference
////
//// ```gherkin
//// @tag1 @tag2
//// Feature: Shopping Cart
////   As a customer
////   I want to manage my cart
////
////   Background:
////     Given I am logged in
////
////   Scenario: Adding items
////     Given I have an empty cart
////     When I add 3 items of "Widget"
////     Then my cart should have 3 items
////
////   Scenario Outline: Multiple products
////     Given I have an empty cart
////     When I add <quantity> items of "<product>"
////     Then my cart should have <quantity> items
////
////     Examples:
////       | quantity | product |
////       | 1        | Widget  |
////       | 5        | Gadget  |
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
/// ```gherkin
/// Given a document with content:
///   """json
///   {"name": "example"}
///   """
/// ```
///
/// ## DataTable
///
/// Tabular data with pipe-delimited rows:
///
/// ```gherkin
/// Given the following users:
///   | name  | email           |
///   | Alice | alice@test.com  |
///   | Bob   | bob@test.com    |
/// ```
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
/// ```gherkin
/// Given I have 5 items in my cart
/// When I remove 2 items
/// Then I should have 3 items
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
/// ## Example
///
/// ```gherkin
/// Background:
///   Given I am logged in as "admin"
///   And I am on the dashboard
/// ```
///
/// These steps run before each scenario, as if they were prepended.
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
/// ```gherkin
/// Examples:
///   | quantity | product |
///   | 1        | Widget  |
///   | 5        | Gadget  |
/// ```
///
/// With a scenario outline:
///
/// ```gherkin
/// When I add <quantity> items of "<product>"
/// ```
///
/// This expands to two scenarios:
/// - "When I add 1 items of \"Widget\""
/// - "When I add 5 items of \"Gadget\""
///
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
/// ## Scenario
///
/// A single test case with fixed steps:
///
/// ```gherkin
/// Scenario: Adding items to cart
///   Given I have an empty cart
///   When I add 3 items
///   Then my cart should have 3 items
/// ```
///
/// ## ScenarioOutline
///
/// A parameterized test with examples table:
///
/// ```gherkin
/// Scenario Outline: Adding products
///   When I add <qty> items of "<name>"
///   Then my cart should have <qty> items
///
///   Examples:
///     | qty | name   |
///     | 1   | Widget |
///     | 5   | Gadget |
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
/// ```gherkin
/// @shopping
/// Feature: Shopping Cart
///   As a customer
///   I want to manage items in my cart
///   So that I can purchase what I need
///
///   Background:
///     Given I am logged in
///
///   Scenario: Empty cart
///     Given I have an empty cart
///     Then my cart count should be 0
///
///   @slow
///   Scenario: Adding items
///     Given I have an empty cart
///     When I add 3 items of "Widget"
///     Then my cart should have 3 items
/// ```
///
pub type Feature {
  Feature(
    /// The feature name (from the Feature: line)
    name: String,
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
/// keyword_to_string(Given)  // -> "Given"
/// keyword_to_string(And)    // -> "And"
/// ```
///
pub fn keyword_to_string(keyword: StepKeyword) -> String {
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
/// keyword_from_string("Given")  // -> Some(Given)
/// keyword_from_string("Hello")  // -> None
/// ```
///
pub fn keyword_from_string(text: String) -> Option(StepKeyword) {
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
/// resolve_keyword(And, Given)  // -> Given
/// resolve_keyword(But, Then)   // -> Then
/// resolve_keyword(When, Given) // -> When (non-And/But unchanged)
/// ```
///
pub fn resolve_keyword(
  keyword: StepKeyword,
  previous: StepKeyword,
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
pub fn empty_examples() -> ExamplesTable {
  ExamplesTable(headers: [], rows: [])
}

/// Create an empty background.
///
/// Useful as a default value or for testing.
///
pub fn empty_background() -> Background {
  Background(steps: [])
}
