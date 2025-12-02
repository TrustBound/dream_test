import dream_test/assertions/should.{equal, fail_with, or_fail_with, should}
import dream_test/gherkin/types as gherkin_types
import dream_test/types.{type AssertionResult, AssertionOk}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}

pub fn tests() {
  describe("Gherkin Types", [
    describe("keyword_to_string", [
      it("converts Given to 'Given'", fn() {
        // Arrange
        let keyword = gherkin_types.Given
        let expected = "Given"

        // Act
        let result = gherkin_types.keyword_to_string(keyword)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Given keyword should convert to 'Given'")
      }),
      it("converts When to 'When'", fn() {
        // Arrange
        let keyword = gherkin_types.When
        let expected = "When"

        // Act
        let result = gherkin_types.keyword_to_string(keyword)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("When keyword should convert to 'When'")
      }),
      it("converts Then to 'Then'", fn() {
        // Arrange
        let keyword = gherkin_types.Then
        let expected = "Then"

        // Act
        let result = gherkin_types.keyword_to_string(keyword)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Then keyword should convert to 'Then'")
      }),
      it("converts And to 'And'", fn() {
        // Arrange
        let keyword = gherkin_types.And
        let expected = "And"

        // Act
        let result = gherkin_types.keyword_to_string(keyword)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("And keyword should convert to 'And'")
      }),
      it("converts But to 'But'", fn() {
        // Arrange
        let keyword = gherkin_types.But
        let expected = "But"

        // Act
        let result = gherkin_types.keyword_to_string(keyword)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("But keyword should convert to 'But'")
      }),
    ]),
    describe("keyword_from_string", [
      it("parses 'Given' to Some(Given)", fn() {
        // Arrange
        let input = "Given"

        // Act
        let result = gherkin_types.keyword_from_string(input)

        // Assert
        case result {
          Some(gherkin_types.Given) -> pass()
          _ -> fail_with("'Given' should parse to Some(Given)")
        }
      }),
      it("parses 'When' to Some(When)", fn() {
        // Arrange
        let input = "When"

        // Act
        let result = gherkin_types.keyword_from_string(input)

        // Assert
        case result {
          Some(gherkin_types.When) -> pass()
          _ -> fail_with("'When' should parse to Some(When)")
        }
      }),
      it("parses 'Then' to Some(Then)", fn() {
        // Arrange
        let input = "Then"

        // Act
        let result = gherkin_types.keyword_from_string(input)

        // Assert
        case result {
          Some(gherkin_types.Then) -> pass()
          _ -> fail_with("'Then' should parse to Some(Then)")
        }
      }),
      it("parses 'And' to Some(And)", fn() {
        // Arrange
        let input = "And"

        // Act
        let result = gherkin_types.keyword_from_string(input)

        // Assert
        case result {
          Some(gherkin_types.And) -> pass()
          _ -> fail_with("'And' should parse to Some(And)")
        }
      }),
      it("parses 'But' to Some(But)", fn() {
        // Arrange
        let input = "But"

        // Act
        let result = gherkin_types.keyword_from_string(input)

        // Assert
        case result {
          Some(gherkin_types.But) -> pass()
          _ -> fail_with("'But' should parse to Some(But)")
        }
      }),
      it("returns None for unknown keyword", fn() {
        // Arrange
        let input = "Unknown"
        let expected = None

        // Act
        let result = gherkin_types.keyword_from_string(input)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Unknown keyword should return None")
      }),
      it("returns None for lowercase 'given'", fn() {
        // Arrange
        let input = "given"
        let expected = None

        // Act
        let result = gherkin_types.keyword_from_string(input)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Lowercase keywords should return None")
      }),
      it("returns None for empty string", fn() {
        // Arrange
        let input = ""
        let expected = None

        // Act
        let result = gherkin_types.keyword_from_string(input)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Empty string should return None")
      }),
    ]),
    describe("resolve_keyword", [
      it("And after Given resolves to Given", fn() {
        // Arrange
        let current = gherkin_types.And
        let previous = gherkin_types.Given

        // Act
        let result = gherkin_types.resolve_keyword(current, previous)

        // Assert
        case result {
          gherkin_types.Given -> pass()
          _ -> fail_with("And should inherit Given from previous")
        }
      }),
      it("And after When resolves to When", fn() {
        // Arrange
        let current = gherkin_types.And
        let previous = gherkin_types.When

        // Act
        let result = gherkin_types.resolve_keyword(current, previous)

        // Assert
        case result {
          gherkin_types.When -> pass()
          _ -> fail_with("And should inherit When from previous")
        }
      }),
      it("And after Then resolves to Then", fn() {
        // Arrange
        let current = gherkin_types.And
        let previous = gherkin_types.Then

        // Act
        let result = gherkin_types.resolve_keyword(current, previous)

        // Assert
        case result {
          gherkin_types.Then -> pass()
          _ -> fail_with("And should inherit Then from previous")
        }
      }),
      it("But after Given resolves to Given", fn() {
        // Arrange
        let current = gherkin_types.But
        let previous = gherkin_types.Given

        // Act
        let result = gherkin_types.resolve_keyword(current, previous)

        // Assert
        case result {
          gherkin_types.Given -> pass()
          _ -> fail_with("But should inherit Given from previous")
        }
      }),
      it("But after When resolves to When", fn() {
        // Arrange
        let current = gherkin_types.But
        let previous = gherkin_types.When

        // Act
        let result = gherkin_types.resolve_keyword(current, previous)

        // Assert
        case result {
          gherkin_types.When -> pass()
          _ -> fail_with("But should inherit When from previous")
        }
      }),
      it("But after Then resolves to Then", fn() {
        // Arrange
        let current = gherkin_types.But
        let previous = gherkin_types.Then

        // Act
        let result = gherkin_types.resolve_keyword(current, previous)

        // Assert
        case result {
          gherkin_types.Then -> pass()
          _ -> fail_with("But should inherit Then from previous")
        }
      }),
      it("Given does not inherit from previous", fn() {
        // Arrange
        let current = gherkin_types.Given
        let previous = gherkin_types.When

        // Act
        let result = gherkin_types.resolve_keyword(current, previous)

        // Assert
        case result {
          gherkin_types.Given -> pass()
          _ -> fail_with("Given should not inherit from previous")
        }
      }),
      it("When does not inherit from previous", fn() {
        // Arrange
        let current = gherkin_types.When
        let previous = gherkin_types.Given

        // Act
        let result = gherkin_types.resolve_keyword(current, previous)

        // Assert
        case result {
          gherkin_types.When -> pass()
          _ -> fail_with("When should not inherit from previous")
        }
      }),
      it("Then does not inherit from previous", fn() {
        // Arrange
        let current = gherkin_types.Then
        let previous = gherkin_types.When

        // Act
        let result = gherkin_types.resolve_keyword(current, previous)

        // Assert
        case result {
          gherkin_types.Then -> pass()
          _ -> fail_with("Then should not inherit from previous")
        }
      }),
      it("And after And returns And", fn() {
        // Arrange
        let current = gherkin_types.And
        let previous = gherkin_types.And

        // Act
        let result = gherkin_types.resolve_keyword(current, previous)

        // Assert
        case result {
          gherkin_types.And -> pass()
          _ -> fail_with("And after And should return And")
        }
      }),
    ]),
    describe("empty_examples", [
      it("creates ExamplesTable with empty headers", fn() {
        // Arrange
        let expected_headers = []

        // Act
        let result = gherkin_types.empty_examples()

        // Assert
        result.headers
        |> should()
        |> equal(expected_headers)
        |> or_fail_with("Empty examples should have empty headers")
      }),
      it("creates ExamplesTable with empty rows", fn() {
        // Arrange
        let expected_rows = []

        // Act
        let result = gherkin_types.empty_examples()

        // Assert
        result.rows
        |> should()
        |> equal(expected_rows)
        |> or_fail_with("Empty examples should have empty rows")
      }),
    ]),
    describe("empty_background", [
      it("creates Background with empty steps", fn() {
        // Arrange
        let expected_steps = []

        // Act
        let result = gherkin_types.empty_background()

        // Assert
        result.steps
        |> should()
        |> equal(expected_steps)
        |> or_fail_with("Empty background should have empty steps")
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
