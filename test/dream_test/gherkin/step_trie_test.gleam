import dream_test/assertions/should.{equal, fail_with, or_fail_with, should}
import dream_test/gherkin/step_trie.{
  type StepSegment, AnyParam, CapturedFloat, CapturedInt, CapturedString,
  CapturedWord, FloatParam, IntParam, LiteralWord, StepMatch, StringParam,
  WordParam, insert, lookup, new, parse_step_pattern, tokenize_step_text,
}
import dream_test/types.{type AssertionResult, AssertionOk}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}

pub fn tests() {
  describe("Step Trie", [
    describe("parse_step_pattern", [
      it("parses simple literal words", fn() {
        // Arrange
        let pattern = "I have items"
        let expected = [
          LiteralWord("I"),
          LiteralWord("have"),
          LiteralWord("items"),
        ]

        // Act
        let result = parse_step_pattern(pattern)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should parse literal words")
      }),
      it("parses {int} placeholder", fn() {
        // Arrange
        let pattern = "I have {int} items"
        let expected = [
          LiteralWord("I"),
          LiteralWord("have"),
          IntParam,
          LiteralWord("items"),
        ]

        // Act
        let result = parse_step_pattern(pattern)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should parse {int} as IntParam")
      }),
      it("parses {float} placeholder", fn() {
        // Arrange
        let pattern = "the price is {float} dollars"
        let expected = [
          LiteralWord("the"),
          LiteralWord("price"),
          LiteralWord("is"),
          FloatParam,
          LiteralWord("dollars"),
        ]

        // Act
        let result = parse_step_pattern(pattern)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should parse {float} as FloatParam")
      }),
      it("parses {string} placeholder", fn() {
        // Arrange
        let pattern = "the user {string} is logged in"
        let expected = [
          LiteralWord("the"),
          LiteralWord("user"),
          StringParam,
          LiteralWord("is"),
          LiteralWord("logged"),
          LiteralWord("in"),
        ]

        // Act
        let result = parse_step_pattern(pattern)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should parse {string} as StringParam")
      }),
      it("parses {word} placeholder", fn() {
        // Arrange
        let pattern = "the {word} button is visible"
        let expected = [
          LiteralWord("the"),
          WordParam,
          LiteralWord("button"),
          LiteralWord("is"),
          LiteralWord("visible"),
        ]

        // Act
        let result = parse_step_pattern(pattern)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should parse {word} as WordParam")
      }),
      it("parses {} anonymous placeholder", fn() {
        // Arrange
        let pattern = "I click {}"
        let expected = [LiteralWord("I"), LiteralWord("click"), AnyParam]

        // Act
        let result = parse_step_pattern(pattern)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should parse {} as AnyParam")
      }),
      it("parses multiple placeholders", fn() {
        // Arrange
        let pattern = "I add {int} items of {string}"
        let expected = [
          LiteralWord("I"),
          LiteralWord("add"),
          IntParam,
          LiteralWord("items"),
          LiteralWord("of"),
          StringParam,
        ]

        // Act
        let result = parse_step_pattern(pattern)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should parse multiple placeholders")
      }),
      it("handles empty pattern", fn() {
        // Arrange
        let pattern = ""
        let expected: List(StepSegment) = []

        // Act
        let result = parse_step_pattern(pattern)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Empty pattern should produce empty segments")
      }),
      it("handles multiple spaces between words", fn() {
        // Arrange
        let pattern = "I   have    items"
        let expected = [
          LiteralWord("I"),
          LiteralWord("have"),
          LiteralWord("items"),
        ]

        // Act
        let result = parse_step_pattern(pattern)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should filter empty segments from multiple spaces")
      }),
    ]),
    describe("tokenize_step_text", [
      it("tokenizes simple words", fn() {
        // Arrange
        let text = "I have items"
        let expected = ["I", "have", "items"]

        // Act
        let result = tokenize_step_text(text)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should tokenize simple words")
      }),
      it("keeps quoted strings together", fn() {
        // Arrange
        let text = "the user \"John Doe\" is logged in"
        let expected = ["the", "user", "\"John Doe\"", "is", "logged", "in"]

        // Act
        let result = tokenize_step_text(text)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should keep quoted strings as single token")
      }),
      it("handles quoted string at start", fn() {
        // Arrange
        let text = "\"Hello\" is displayed"
        let expected = ["\"Hello\"", "is", "displayed"]

        // Act
        let result = tokenize_step_text(text)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should handle quoted string at start")
      }),
      it("handles quoted string at end", fn() {
        // Arrange
        let text = "I see \"Goodbye\""
        let expected = ["I", "see", "\"Goodbye\""]

        // Act
        let result = tokenize_step_text(text)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should handle quoted string at end")
      }),
      it("handles multiple quoted strings", fn() {
        // Arrange
        let text = "\"A\" and \"B\" are values"
        let expected = ["\"A\"", "and", "\"B\"", "are", "values"]

        // Act
        let result = tokenize_step_text(text)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Should handle multiple quoted strings")
      }),
      it("handles empty text", fn() {
        // Arrange
        let text = ""
        let expected: List(String) = []

        // Act
        let result = tokenize_step_text(text)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Empty text should produce empty tokens")
      }),
    ]),
    describe("new and insert", [
      it("creates empty trie that finds nothing", fn() {
        // Arrange
        let trie = new()

        // Act
        let result = lookup(trie, "Given", "anything")

        // Assert
        case result {
          None -> pass()
          Some(_) -> fail_with("Empty trie should not match anything")
        }
      }),
      it("inserts and retrieves single pattern", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "I have items", "handler1")

        // Act
        let result = lookup(trie, "Given", "I have items")

        // Assert
        case result {
          Some(StepMatch(handler, captures)) -> {
            case handler == "handler1" && captures == [] {
              True -> pass()
              False ->
                fail_with("Should match with correct handler and no captures")
            }
          }
          None -> fail_with("Should find inserted pattern")
        }
      }),
      it("replaces handler for same keyword and pattern", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "I have items", "handler1")
          |> insert("Given", "I have items", "handler2")

        // Act
        let result = lookup(trie, "Given", "I have items")

        // Assert
        case result {
          Some(StepMatch(handler, _)) -> {
            case handler == "handler2" {
              True -> pass()
              False -> fail_with("Should use latest handler")
            }
          }
          None -> fail_with("Should find pattern")
        }
      }),
      it("allows same pattern for different keywords", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "something happens", "given_handler")
          |> insert("When", "something happens", "when_handler")

        // Act
        let given_result = lookup(trie, "Given", "something happens")
        let when_result = lookup(trie, "When", "something happens")

        // Assert
        case given_result, when_result {
          Some(StepMatch(g, _)), Some(StepMatch(w, _)) -> {
            case g == "given_handler" && w == "when_handler" {
              True -> pass()
              False -> fail_with("Each keyword should have its own handler")
            }
          }
          _, _ -> fail_with("Should find both patterns")
        }
      }),
    ]),
    describe("lookup with literals", [
      it("matches exact literal pattern", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "I have an empty cart", "handler")

        // Act
        let result = lookup(trie, "Given", "I have an empty cart")

        // Assert
        case result {
          Some(StepMatch(_, [])) -> pass()
          Some(_) -> fail_with("Should have no captures for literal pattern")
          None -> fail_with("Should match exact literal pattern")
        }
      }),
      it("does not match wrong keyword", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "I have items", "handler")

        // Act
        let result = lookup(trie, "When", "I have items")

        // Assert
        case result {
          None -> pass()
          Some(_) -> fail_with("Should not match different keyword")
        }
      }),
      it("does not match partial pattern", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "I have many items", "handler")

        // Act
        let result = lookup(trie, "Given", "I have")

        // Assert
        case result {
          None -> pass()
          Some(_) -> fail_with("Should not match partial pattern")
        }
      }),
      it("does not match extended text", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "I have items", "handler")

        // Act
        let result = lookup(trie, "Given", "I have items today")

        // Assert
        case result {
          None -> pass()
          Some(_) -> fail_with("Should not match text with extra words")
        }
      }),
    ]),
    describe("lookup with {int}", [
      it("captures integer value", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "I have {int} items", "handler")

        // Act
        let result = lookup(trie, "Given", "I have 42 items")

        // Assert
        case result {
          Some(StepMatch(_, [CapturedInt(42)])) -> pass()
          Some(StepMatch(_, _captures)) ->
            fail_with("Expected CapturedInt(42), got different captures")
          None -> fail_with("Should match pattern with int")
        }
      }),
      it("captures negative integer", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "the temperature is {int} degrees", "handler")

        // Act
        let result = lookup(trie, "Given", "the temperature is -5 degrees")

        // Assert
        case result {
          Some(StepMatch(_, [CapturedInt(-5)])) -> pass()
          _ -> fail_with("Should capture negative integer")
        }
      }),
      it("captures zero", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "I have {int} items", "handler")

        // Act
        let result = lookup(trie, "Given", "I have 0 items")

        // Assert
        case result {
          Some(StepMatch(_, [CapturedInt(0)])) -> pass()
          _ -> fail_with("Should capture zero")
        }
      }),
      it("does not match non-integer where int expected", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "I have {int} items", "handler")

        // Act
        let result = lookup(trie, "Given", "I have many items")

        // Assert
        case result {
          None -> pass()
          Some(_) -> fail_with("Should not match non-integer for {int}")
        }
      }),
    ]),
    describe("lookup with {float}", [
      it("captures float value", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "the price is {float} dollars", "handler")

        // Act
        let result = lookup(trie, "Given", "the price is 3.14 dollars")

        // Assert
        case result {
          Some(StepMatch(_, [CapturedFloat(f)])) -> {
            // Float comparison with tolerance
            case f >. 3.13 && f <. 3.15 {
              True -> pass()
              False -> fail_with("Should capture 3.14")
            }
          }
          _ -> fail_with("Should match pattern with float")
        }
      }),
      it("captures negative float", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "the balance is {float}", "handler")

        // Act
        let result = lookup(trie, "Given", "the balance is -99.5")

        // Assert
        case result {
          Some(StepMatch(_, [CapturedFloat(f)])) -> {
            case f <. -99.4 && f >. -99.6 {
              True -> pass()
              False -> fail_with("Should capture -99.5")
            }
          }
          _ -> fail_with("Should capture negative float")
        }
      }),
    ]),
    describe("lookup with {string}", [
      it("captures quoted string", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "the user {string} is logged in", "handler")

        // Act
        let result = lookup(trie, "Given", "the user \"John Doe\" is logged in")

        // Assert
        case result {
          Some(StepMatch(_, [CapturedString("John Doe")])) -> pass()
          _ -> fail_with("Should capture quoted string without quotes")
        }
      }),
      it("captures empty quoted string", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "the message is {string}", "handler")

        // Act
        let result = lookup(trie, "Given", "the message is \"\"")

        // Assert
        case result {
          Some(StepMatch(_, [CapturedString("")])) -> pass()
          _ -> fail_with("Should capture empty string")
        }
      }),
      it("does not match unquoted text for {string}", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "the user {string} is logged in", "handler")

        // Act
        let result = lookup(trie, "Given", "the user John is logged in")

        // Assert
        case result {
          None -> pass()
          Some(_) -> fail_with("Should not match unquoted text for {string}")
        }
      }),
    ]),
    describe("lookup with {word}", [
      it("captures single word", fn() {
        // Arrange
        let trie =
          new()
          |> insert("When", "I click the {word} button", "handler")

        // Act
        let result = lookup(trie, "When", "I click the submit button")

        // Assert
        case result {
          Some(StepMatch(_, [CapturedWord("submit")])) -> pass()
          _ -> fail_with("Should capture single word")
        }
      }),
    ]),
    describe("lookup with {}", [
      it("captures any word", fn() {
        // Arrange
        let trie =
          new()
          |> insert("When", "I click {}", "handler")

        // Act
        let result = lookup(trie, "When", "I click anywhere")

        // Assert
        case result {
          Some(StepMatch(_, [CapturedWord("anywhere")])) -> pass()
          _ -> fail_with("Should capture any word")
        }
      }),
    ]),
    describe("lookup with multiple captures", [
      it("captures multiple values in order", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "I add {int} items of {string}", "handler")

        // Act
        let result = lookup(trie, "Given", "I add 5 items of \"Widget\"")

        // Assert
        case result {
          Some(StepMatch(_, [CapturedInt(5), CapturedString("Widget")])) ->
            pass()
          Some(StepMatch(_, _captures)) ->
            fail_with("Expected [CapturedInt(5), CapturedString(Widget)]")
          None -> fail_with("Should match with multiple captures")
        }
      }),
      it("captures three values", fn() {
        // Arrange
        let trie =
          new()
          |> insert(
            "Given",
            "{string} has {int} items at {float} each",
            "handler",
          )

        // Act
        let result = lookup(trie, "Given", "\"Cart\" has 10 items at 5.99 each")

        // Assert
        case result {
          Some(StepMatch(
            _,
            [CapturedString("Cart"), CapturedInt(10), CapturedFloat(f)],
          )) -> {
            case f >. 5.98 && f <. 6.0 {
              True -> pass()
              False -> fail_with("Float should be ~5.99")
            }
          }
          _ -> fail_with("Should capture three values")
        }
      }),
    ]),
    describe("lookup priority", [
      it("prefers literal over parameter", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "I have {int} items", "int_handler")
          |> insert("Given", "I have many items", "literal_handler")

        // Act
        let result = lookup(trie, "Given", "I have many items")

        // Assert
        case result {
          Some(StepMatch(handler, [])) -> {
            case handler == "literal_handler" {
              True -> pass()
              False -> fail_with("Should prefer literal match")
            }
          }
          _ -> fail_with("Should match literal pattern")
        }
      }),
      it("uses int handler when no literal matches", fn() {
        // Arrange
        let trie =
          new()
          |> insert("Given", "I have {int} items", "int_handler")
          |> insert("Given", "I have many items", "literal_handler")

        // Act
        let result = lookup(trie, "Given", "I have 42 items")

        // Assert
        case result {
          Some(StepMatch(handler, [CapturedInt(42)])) -> {
            case handler == "int_handler" {
              True -> pass()
              False -> fail_with("Should use int handler")
            }
          }
          _ -> fail_with("Should fall back to int pattern")
        }
      }),
    ]),
    describe("wildcard keyword", [
      it("matches wildcard when exact keyword not found", fn() {
        // Arrange
        let trie =
          new()
          |> insert("*", "something happens", "wildcard_handler")

        // Act
        let given_result = lookup(trie, "Given", "something happens")
        let when_result = lookup(trie, "When", "something happens")

        // Assert
        case given_result, when_result {
          Some(StepMatch(g, _)), Some(StepMatch(w, _)) -> {
            case g == "wildcard_handler" && w == "wildcard_handler" {
              True -> pass()
              False -> fail_with("Wildcard should match any keyword")
            }
          }
          _, _ -> fail_with("Should match with wildcard")
        }
      }),
      it("prefers exact keyword over wildcard", fn() {
        // Arrange
        let trie =
          new()
          |> insert("*", "something happens", "wildcard_handler")
          |> insert("Given", "something happens", "given_handler")

        // Act
        let result = lookup(trie, "Given", "something happens")

        // Assert
        case result {
          Some(StepMatch(handler, _)) -> {
            case handler == "given_handler" {
              True -> pass()
              False -> fail_with("Should prefer exact keyword over wildcard")
            }
          }
          None -> fail_with("Should find match")
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
