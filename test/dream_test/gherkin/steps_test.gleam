import dream_test/assertions/should.{equal, fail_with, or_fail_with, should}
import dream_test/gherkin/step_trie.{
  CapturedFloat, CapturedInt, CapturedString, CapturedWord,
}
import dream_test/gherkin/steps.{
  capture_count, find_step, get_float, get_int, get_string, get_word, given,
  new_registry, step, then_, when_,
}
import dream_test/gherkin/types as gherkin_types
import dream_test/types.{type AssertionResult, AssertionOk}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Gherkin Steps", [
    describe("new_registry", [
      it("creates empty registry that finds no steps", fn() {
        // Arrange
        let registry = new_registry()

        // Act
        let result = find_step(registry, gherkin_types.Given, "anything")

        // Assert
        case result {
          Error(_) -> pass()
          Ok(_) -> fail_with("Empty registry should find no steps")
        }
      }),
    ]),
    describe("given", [
      it("registers and finds Given step", fn() {
        // Arrange
        let registry =
          new_registry()
          |> given("I have items", passing_handler)

        // Act
        let result = find_step(registry, gherkin_types.Given, "I have items")

        // Assert
        case result {
          Ok(_) -> pass()
          Error(msg) -> fail_with("Should find Given step: " <> msg)
        }
      }),
      it("does not match Given step with When keyword", fn() {
        // Arrange
        let registry =
          new_registry()
          |> given("I have items", passing_handler)

        // Act
        let result = find_step(registry, gherkin_types.When, "I have items")

        // Assert
        case result {
          Error(_) -> pass()
          Ok(_) -> fail_with("Given step should not match When keyword")
        }
      }),
    ]),
    describe("when_", [
      it("registers and finds When step", fn() {
        // Arrange
        let registry =
          new_registry()
          |> when_("I add items", passing_handler)

        // Act
        let result = find_step(registry, gherkin_types.When, "I add items")

        // Assert
        case result {
          Ok(_) -> pass()
          Error(msg) -> fail_with("Should find When step: " <> msg)
        }
      }),
      it("does not match When step with Then keyword", fn() {
        // Arrange
        let registry =
          new_registry()
          |> when_("I add items", passing_handler)

        // Act
        let result = find_step(registry, gherkin_types.Then, "I add items")

        // Assert
        case result {
          Error(_) -> pass()
          Ok(_) -> fail_with("When step should not match Then keyword")
        }
      }),
    ]),
    describe("then_", [
      it("registers and finds Then step", fn() {
        // Arrange
        let registry =
          new_registry()
          |> then_("I should see results", passing_handler)

        // Act
        let result =
          find_step(registry, gherkin_types.Then, "I should see results")

        // Assert
        case result {
          Ok(_) -> pass()
          Error(msg) -> fail_with("Should find Then step: " <> msg)
        }
      }),
    ]),
    describe("step", [
      it("registers step that matches Given keyword", fn() {
        // Arrange
        let registry =
          new_registry()
          |> step("something happens", passing_handler)

        // Act
        let result =
          find_step(registry, gherkin_types.Given, "something happens")

        // Assert
        case result {
          Ok(_) -> pass()
          Error(_) -> fail_with("Wildcard step should match Given")
        }
      }),
      it("registers step that matches When keyword", fn() {
        // Arrange
        let registry =
          new_registry()
          |> step("something happens", passing_handler)

        // Act
        let result =
          find_step(registry, gherkin_types.When, "something happens")

        // Assert
        case result {
          Ok(_) -> pass()
          Error(_) -> fail_with("Wildcard step should match When")
        }
      }),
      it("registers step that matches Then keyword", fn() {
        // Arrange
        let registry =
          new_registry()
          |> step("something happens", passing_handler)

        // Act
        let result =
          find_step(registry, gherkin_types.Then, "something happens")

        // Assert
        case result {
          Ok(_) -> pass()
          Error(_) -> fail_with("Wildcard step should match Then")
        }
      }),
    ]),
    describe("find_step with And/But", [
      it("And inherits from Given context - finds Given handler", fn() {
        // Arrange
        let registry =
          new_registry()
          |> given("some condition", passing_handler)

        // Note: And/But resolve to their parent keyword in practice
        // The find_step function itself doesn't resolve - that's done at execution time
        // So And/But searches match "And" and "But" respectively in the trie
        // This test verifies the registry lookup behavior

        // Act
        let result = find_step(registry, gherkin_types.And, "some condition")

        // Assert - And keyword itself doesn't find Given step
        case result {
          Error(_) -> pass()
          Ok(_) -> fail_with("And keyword should not directly find Given step")
        }
      }),
    ]),
    describe("find_step with captures", [
      it("captures integer from {int} pattern", fn() {
        // Arrange
        let registry =
          new_registry()
          |> given("I have {int} items", passing_handler)

        // Act
        let result = find_step(registry, gherkin_types.Given, "I have 42 items")

        // Assert
        case result {
          Ok(match) -> {
            case match.captures {
              [CapturedInt(42)] -> pass()
              _ -> fail_with("Should capture integer 42")
            }
          }
          Error(msg) -> fail_with("Should find step: " <> msg)
        }
      }),
      it("captures string from {string} pattern", fn() {
        // Arrange
        let registry =
          new_registry()
          |> given("I see {string}", passing_handler)

        // Act
        let result =
          find_step(registry, gherkin_types.Given, "I see \"Hello World\"")

        // Assert
        case result {
          Ok(match) -> {
            case match.captures {
              [CapturedString("Hello World")] -> pass()
              _ -> fail_with("Should capture string 'Hello World'")
            }
          }
          Error(msg) -> fail_with("Should find step: " <> msg)
        }
      }),
      it("captures multiple values", fn() {
        // Arrange
        let registry =
          new_registry()
          |> given("I add {int} of {string}", passing_handler)

        // Act
        let result =
          find_step(registry, gherkin_types.Given, "I add 5 of \"Widget\"")

        // Assert
        case result {
          Ok(match) -> {
            case match.captures {
              [CapturedInt(5), CapturedString("Widget")] -> pass()
              _ -> fail_with("Should capture int and string")
            }
          }
          Error(msg) -> fail_with("Should find step: " <> msg)
        }
      }),
    ]),
    describe("find_step error messages", [
      it("returns descriptive error for undefined step", fn() {
        // Arrange
        let registry = new_registry()

        // Act
        let result =
          find_step(registry, gherkin_types.Given, "something undefined")

        // Assert
        case result {
          Error(msg) -> {
            case msg == "Undefined step: Given something undefined" {
              True -> pass()
              False -> fail_with("Error should include keyword and text")
            }
          }
          Ok(_) -> fail_with("Should return error")
        }
      }),
    ]),
    describe("get_int", [
      it("extracts int at valid index", fn() {
        // Arrange
        let captures = [CapturedInt(42), CapturedString("test")]
        let expected = Ok(42)

        // Act
        let result = get_int(captures, 0)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should extract int at index 0")
      }),
      it("returns error for non-int at index", fn() {
        // Arrange
        let captures = [CapturedString("test")]

        // Act
        let result = get_int(captures, 0)

        // Assert
        case result {
          Error(_) -> pass()
          Ok(_) -> fail_with("Should error for non-int")
        }
      }),
      it("returns error for out of bounds index", fn() {
        // Arrange
        let captures = [CapturedInt(42)]

        // Act
        let result = get_int(captures, 5)

        // Assert
        case result {
          Error(_) -> pass()
          Ok(_) -> fail_with("Should error for out of bounds")
        }
      }),
    ]),
    describe("get_float", [
      it("extracts float at valid index", fn() {
        // Arrange
        let captures = [CapturedFloat(3.14)]

        // Act
        let result = get_float(captures, 0)

        // Assert
        case result {
          Ok(f) -> {
            case f >. 3.13 && f <. 3.15 {
              True -> pass()
              False -> fail_with("Should extract float ~3.14")
            }
          }
          Error(_) -> fail_with("Should extract float")
        }
      }),
      it("returns error for non-float at index", fn() {
        // Arrange
        let captures = [CapturedInt(42)]

        // Act
        let result = get_float(captures, 0)

        // Assert
        case result {
          Error(_) -> pass()
          Ok(_) -> fail_with("Should error for non-float")
        }
      }),
    ]),
    describe("get_string", [
      it("extracts CapturedString at valid index", fn() {
        // Arrange
        let captures = [CapturedString("hello")]
        let expected = Ok("hello")

        // Act
        let result = get_string(captures, 0)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should extract string")
      }),
      it("extracts CapturedWord as string", fn() {
        // Arrange
        let captures = [CapturedWord("word")]
        let expected = Ok("word")

        // Act
        let result = get_string(captures, 0)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should extract word as string")
      }),
      it("returns error for non-string at index", fn() {
        // Arrange
        let captures = [CapturedInt(42)]

        // Act
        let result = get_string(captures, 0)

        // Assert
        case result {
          Error(_) -> pass()
          Ok(_) -> fail_with("Should error for non-string")
        }
      }),
    ]),
    describe("get_word", [
      it("extracts CapturedWord at valid index", fn() {
        // Arrange
        let captures = [CapturedWord("myword")]
        let expected = Ok("myword")

        // Act
        let result = get_word(captures, 0)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should extract word")
      }),
      it("extracts CapturedString as word", fn() {
        // Arrange
        let captures = [CapturedString("quoted")]
        let expected = Ok("quoted")

        // Act
        let result = get_word(captures, 0)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should extract string as word")
      }),
    ]),
    describe("capture_count", [
      it("returns 0 for empty captures", fn() {
        // Arrange
        let captures = []
        let expected = 0

        // Act
        let result = capture_count(captures)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Empty captures should have count 0")
      }),
      it("returns correct count for multiple captures", fn() {
        // Arrange
        let captures = [
          CapturedInt(1),
          CapturedString("two"),
          CapturedFloat(3.0),
        ]
        let expected = 3

        // Act
        let result = capture_count(captures)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should count all captures")
      }),
    ]),
    describe("chained registration", [
      it("supports chaining multiple step types", fn() {
        // Arrange
        let registry =
          new_registry()
          |> given("a precondition", passing_handler)
          |> when_("an action", passing_handler)
          |> then_("an outcome", passing_handler)

        // Act
        let given_result =
          find_step(registry, gherkin_types.Given, "a precondition")
        let when_result = find_step(registry, gherkin_types.When, "an action")
        let then_result = find_step(registry, gherkin_types.Then, "an outcome")

        // Assert
        case given_result, when_result, then_result {
          Ok(_), Ok(_), Ok(_) -> pass()
          _, _, _ -> fail_with("All step types should be registered")
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

fn passing_handler(_context: steps.StepContext) -> AssertionResult {
  AssertionOk
}
