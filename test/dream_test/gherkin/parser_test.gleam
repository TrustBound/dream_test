import dream_test/assertions/should.{
  equal, fail_with, have_length, or_fail_with, should,
}
import dream_test/gherkin/parser.{parse_string}
import dream_test/gherkin/types as gherkin_types
import dream_test/types.{type AssertionResult, AssertionOk}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}

pub fn tests() {
  describe("Gherkin Parser", [
    describe("parse_string with minimal feature", [
      it("parses feature name", fn() {
        // Arrange
        let content =
          "Feature: Shopping Cart
"
        let expected = "Shopping Cart"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) ->
            feature.name
            |> should()
            |> equal(expected)
            |> or_fail_with("Feature name should be 'Shopping Cart'")
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
      it("returns error for empty content", fn() {
        // Arrange
        let content = ""

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Error(_) -> pass()
          Ok(_) -> fail_with("Should return error for empty content")
        }
      }),
      it("returns error for content without Feature keyword", fn() {
        // Arrange
        let content = "Scenario: Something"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Error(_) -> pass()
          Ok(_) -> fail_with("Should return error without Feature keyword")
        }
      }),
    ]),
    describe("parse_string with feature description", [
      it("parses feature description", fn() {
        // Arrange
        let content =
          "Feature: Shopping Cart
  As a customer
  I want to manage my cart
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) -> {
            case feature.description {
              Some(desc) -> {
                case desc == "As a customer\nI want to manage my cart" {
                  True -> pass()
                  False -> fail_with("Description should match expected")
                }
              }
              None -> fail_with("Should have description")
            }
          }
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
    ]),
    describe("parse_string with tags", [
      it("parses single feature tag", fn() {
        // Arrange
        let content =
          "@smoke
Feature: Tagged Feature
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) ->
            feature.tags
            |> should()
            |> equal(["smoke"])
            |> or_fail_with("Feature should have 'smoke' tag")
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
      it("parses multiple feature tags", fn() {
        // Arrange
        let content =
          "@smoke @regression @priority-high
Feature: Multi-tagged Feature
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) ->
            feature.tags
            |> should()
            |> equal(["smoke", "regression", "priority-high"])
            |> or_fail_with("Feature should have all tags")
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
    ]),
    describe("parse_string with scenarios", [
      it("parses single scenario", fn() {
        // Arrange
        let content =
          "Feature: Shopping
  Scenario: Add item
    Given I have a cart
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) ->
            feature.scenarios
            |> should()
            |> have_length(1)
            |> or_fail_with("Should have one scenario")
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
      it("parses scenario name", fn() {
        // Arrange
        let content =
          "Feature: Shopping
  Scenario: Add item to cart
    Given I have a cart
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) -> {
            case feature.scenarios {
              [scenario] -> {
                case scenario {
                  gherkin_types.Scenario(name, _, _) ->
                    name
                    |> should()
                    |> equal("Add item to cart")
                    |> or_fail_with("Scenario name should match")
                  gherkin_types.ScenarioOutline(_, _, _, _) ->
                    fail_with("Should be Scenario, not ScenarioOutline")
                }
              }
              _ -> fail_with("Should have exactly one scenario")
            }
          }
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
      it("parses multiple scenarios", fn() {
        // Arrange
        let content =
          "Feature: Shopping
  Scenario: Add item
    Given I have a cart

  Scenario: Remove item
    Given I have a full cart
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) ->
            feature.scenarios
            |> should()
            |> have_length(2)
            |> or_fail_with("Should have two scenarios")
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
      it("parses scenario tags", fn() {
        // Arrange
        let content =
          "Feature: Shopping
  @wip @important
  Scenario: Tagged scenario
    Given something
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) -> {
            case feature.scenarios {
              [scenario] -> {
                case scenario {
                  gherkin_types.Scenario(_, tags, _) ->
                    tags
                    |> should()
                    |> equal(["wip", "important"])
                    |> or_fail_with("Scenario should have tags")
                  _ -> fail_with("Should be Scenario")
                }
              }
              _ -> fail_with("Should have one scenario")
            }
          }
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
    ]),
    describe("parse_string with steps", [
      it("parses Given step", fn() {
        // Arrange
        let content =
          "Feature: Test
  Scenario: Test
    Given I have something
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) -> {
            case feature.scenarios {
              [gherkin_types.Scenario(_, _, steps)] -> {
                case steps {
                  [gherkin_types.Step(gherkin_types.Given, text, _)] ->
                    text
                    |> should()
                    |> equal("I have something")
                    |> or_fail_with("Step text should match")
                  _ -> fail_with("Should have one Given step")
                }
              }
              _ -> fail_with("Should have one scenario")
            }
          }
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
      it("parses When step", fn() {
        // Arrange
        let content =
          "Feature: Test
  Scenario: Test
    When I do something
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) -> {
            case feature.scenarios {
              [
                gherkin_types.Scenario(
                  _,
                  _,
                  [gherkin_types.Step(keyword, _, _)],
                ),
              ] -> {
                case keyword {
                  gherkin_types.When -> pass()
                  _ -> fail_with("Should be When keyword")
                }
              }
              _ -> fail_with("Should have one scenario with one step")
            }
          }
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
      it("parses Then step", fn() {
        // Arrange
        let content =
          "Feature: Test
  Scenario: Test
    Then I see something
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) -> {
            case feature.scenarios {
              [
                gherkin_types.Scenario(
                  _,
                  _,
                  [gherkin_types.Step(keyword, _, _)],
                ),
              ] -> {
                case keyword {
                  gherkin_types.Then -> pass()
                  _ -> fail_with("Should be Then keyword")
                }
              }
              _ -> fail_with("Should have one scenario with one step")
            }
          }
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
      it("parses And step", fn() {
        // Arrange
        let content =
          "Feature: Test
  Scenario: Test
    Given something
    And something else
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) -> {
            case feature.scenarios {
              [
                gherkin_types.Scenario(
                  _,
                  _,
                  [_, gherkin_types.Step(keyword, _, _)],
                ),
              ] -> {
                case keyword {
                  gherkin_types.And -> pass()
                  _ -> fail_with("Should be And keyword")
                }
              }
              _ -> fail_with("Should have scenario with two steps")
            }
          }
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
      it("parses But step", fn() {
        // Arrange
        let content =
          "Feature: Test
  Scenario: Test
    Given something
    But not something else
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) -> {
            case feature.scenarios {
              [
                gherkin_types.Scenario(
                  _,
                  _,
                  [_, gherkin_types.Step(keyword, _, _)],
                ),
              ] -> {
                case keyword {
                  gherkin_types.But -> pass()
                  _ -> fail_with("Should be But keyword")
                }
              }
              _ -> fail_with("Should have scenario with two steps")
            }
          }
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
      it("parses full Given-When-Then sequence", fn() {
        // Arrange
        let content =
          "Feature: Test
  Scenario: Full flow
    Given I have a cart
    When I add an item
    Then I should see 1 item
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) -> {
            case feature.scenarios {
              [gherkin_types.Scenario(_, _, steps)] ->
                steps
                |> should()
                |> have_length(3)
                |> or_fail_with("Should have three steps")
              _ -> fail_with("Should have one scenario")
            }
          }
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
    ]),
    describe("parse_string with background", [
      it("parses background steps", fn() {
        // Arrange
        let content =
          "Feature: Test
  Background:
    Given I am logged in

  Scenario: Test
    When I do something
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) -> {
            case feature.background {
              Some(bg) ->
                bg.steps
                |> should()
                |> have_length(1)
                |> or_fail_with("Background should have one step")
              None -> fail_with("Should have background")
            }
          }
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
    ]),
    describe("parse_string with data tables", [
      it("parses step with data table", fn() {
        // Arrange
        let content =
          "Feature: Test
  Scenario: Table test
    Given the following users:
      | name  | age |
      | Alice | 30  |
      | Bob   | 25  |
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) -> {
            case feature.scenarios {
              [
                gherkin_types.Scenario(
                  _,
                  _,
                  [gherkin_types.Step(_, _, Some(arg))],
                ),
              ] -> {
                case arg {
                  gherkin_types.DataTable(rows) ->
                    rows
                    |> should()
                    |> have_length(3)
                    |> or_fail_with("Should have header + 2 data rows")
                  _ -> fail_with("Should be DataTable")
                }
              }
              _ -> fail_with("Should have one scenario with one step")
            }
          }
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
    ]),
    describe("parse_string with doc strings", [
      it("parses step with doc string", fn() {
        // Arrange
        let content =
          "Feature: Test
  Scenario: DocString test
    Given the following JSON:
      \"\"\"
      {
        \"key\": \"value\"
      }
      \"\"\"
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) -> {
            case feature.scenarios {
              [
                gherkin_types.Scenario(
                  _,
                  _,
                  [gherkin_types.Step(_, _, Some(arg))],
                ),
              ] -> {
                case arg {
                  gherkin_types.DocString(content, _) -> {
                    case content != "" {
                      True -> pass()
                      False -> fail_with("DocString should have content")
                    }
                  }
                  _ -> fail_with("Should be DocString")
                }
              }
              _ -> fail_with("Should have one scenario with one step")
            }
          }
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
    ]),
    describe("parse_string with scenario outline", [
      it("parses scenario outline with examples", fn() {
        // Arrange
        let content =
          "Feature: Test
  Scenario Outline: Parameterized test
    Given I have <count> items
    Then I should see <count> items

    Examples:
      | count |
      | 1     |
      | 5     |
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) -> {
            case feature.scenarios {
              [gherkin_types.ScenarioOutline(_, _, _, examples)] -> {
                case
                  examples.headers == ["count"]
                  && examples.rows == [["1"], ["5"]]
                {
                  True -> pass()
                  False ->
                    fail_with("Examples should have correct headers and rows")
                }
              }
              _ -> fail_with("Should have one ScenarioOutline")
            }
          }
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
    ]),
    describe("parse_string with comments", [
      it("ignores comment lines", fn() {
        // Arrange
        let content =
          "# This is a comment
Feature: Test
  # Another comment
  Scenario: Test
    # Step comment
    Given something
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) ->
            feature.name
            |> should()
            |> equal("Test")
            |> or_fail_with("Should parse feature ignoring comments")
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
    ]),
    describe("parse_string edge cases", [
      it("handles feature with no scenarios", fn() {
        // Arrange
        let content =
          "Feature: Empty Feature
  Just a description
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) ->
            feature.scenarios
            |> should()
            |> equal([])
            |> or_fail_with("Feature should have no scenarios")
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
      it("handles extra whitespace", fn() {
        // Arrange
        let content =
          "  Feature:   Whitespace Test  
    Scenario:   Spaced Scenario  
      Given   spaced step  
"

        // Act
        let result = parse_string(content)

        // Assert
        case result {
          Ok(feature) ->
            feature.name
            |> should()
            |> equal("Whitespace Test")
            |> or_fail_with("Should trim whitespace from feature name")
          Error(msg) -> fail_with("Parse failed: " <> msg)
        }
      }),
    ]),
  ])
}

// =============================================================================
// Test Helpers
// =============================================================================

fn pass() -> AssertionResult {
  AssertionOk
}
