import dream_test/assertions/should.{
  be_error, be_ok, be_true, equal, or_fail_with, should,
}
import dream_test/gherkin/step_trie.{
  CapturedFloat, CapturedInt, CapturedString, CapturedWord,
}
import dream_test/gherkin/steps.{
  capture_count, find_step, get_float, get_int, get_string, get_word, given,
  new_registry, step, then_, when_,
}
import dream_test/gherkin/types as gherkin_types
import dream_test/types.{type AssertionResult, AssertionOk}
import dream_test/unit.{describe, group, it}
import gleam/result

fn ok_step(_context: steps.StepContext) -> Result(AssertionResult, String) {
  Ok(AssertionOk)
}

pub fn tests() {
  describe("Gherkin Steps", [
    group("new_registry", [
      it("creates empty registry that finds no steps", fn(_) {
        // Arrange
        let registry = new_registry()

        // Act
        let result = find_step(registry, gherkin_types.Given, "anything")

        // Assert
        result
        |> should()
        |> be_error()
        |> or_fail_with("Empty registry should find no steps")
      }),
    ]),
    group("given", [
      it("registers and finds Given step", fn(_) {
        // Arrange
        let registry =
          new_registry()
          |> given("I have items", ok_step)

        // Act
        let result = find_step(registry, gherkin_types.Given, "I have items")

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should find Given step")
      }),
      it("does not match Given step with When keyword", fn(_) {
        // Arrange
        let registry =
          new_registry()
          |> given("I have items", ok_step)

        // Act
        let result = find_step(registry, gherkin_types.When, "I have items")

        // Assert
        result
        |> should()
        |> be_error()
        |> or_fail_with("Given step should not match When keyword")
      }),
    ]),
    group("when_", [
      it("registers and finds When step", fn(_) {
        // Arrange
        let registry =
          new_registry()
          |> when_("I add items", ok_step)

        // Act
        let result = find_step(registry, gherkin_types.When, "I add items")

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should find When step")
      }),
      it("does not match When step with Then keyword", fn(_) {
        // Arrange
        let registry =
          new_registry()
          |> when_("I add items", ok_step)

        // Act
        let result = find_step(registry, gherkin_types.Then, "I add items")

        // Assert
        result
        |> should()
        |> be_error()
        |> or_fail_with("When step should not match Then keyword")
      }),
    ]),
    group("then_", [
      it("registers and finds Then step", fn(_) {
        // Arrange
        let registry =
          new_registry()
          |> then_("I should see results", ok_step)

        // Act
        let result =
          find_step(registry, gherkin_types.Then, "I should see results")

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Should find Then step")
      }),
    ]),
    group("step", [
      it("registers step that matches Given keyword", fn(_) {
        // Arrange
        let registry =
          new_registry()
          |> step("something happens", ok_step)

        // Act
        let result =
          find_step(registry, gherkin_types.Given, "something happens")

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Wildcard step should match Given")
      }),
      it("registers step that matches When keyword", fn(_) {
        // Arrange
        let registry =
          new_registry()
          |> step("something happens", ok_step)

        // Act
        let result =
          find_step(registry, gherkin_types.When, "something happens")

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Wildcard step should match When")
      }),
      it("registers step that matches Then keyword", fn(_) {
        // Arrange
        let registry =
          new_registry()
          |> step("something happens", ok_step)

        // Act
        let result =
          find_step(registry, gherkin_types.Then, "something happens")

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("Wildcard step should match Then")
      }),
    ]),
    group("find_step with And/But", [
      it("And inherits from Given context - finds Given handler", fn(_) {
        // Arrange
        let registry =
          new_registry()
          |> given("some condition", ok_step)

        // Note: And/But resolve to their parent keyword in practice
        // The find_step function itself doesn't resolve - that's done at execution time
        // So And/But searches match "And" and "But" respectively in the trie
        // This test verifies the registry lookup behavior

        // Act
        let result = find_step(registry, gherkin_types.And, "some condition")

        // Assert - And keyword itself doesn't find Given step
        result
        |> should()
        |> be_error()
        |> or_fail_with("And keyword should not directly find Given step")
      }),
    ]),
    group("find_step with captures", [
      it("captures integer from {int} pattern", fn(_) {
        // Arrange
        let registry =
          new_registry()
          |> given("I have {int} items", ok_step)

        // Act
        let captures_result =
          find_step(registry, gherkin_types.Given, "I have 42 items")
          |> result.map(fn(m) { m.captures })

        // Assert
        captures_result
        |> should()
        |> be_ok()
        |> equal([CapturedInt(42)])
        |> or_fail_with("Should capture integer 42")
      }),
      it("captures string from {string} pattern", fn(_) {
        // Arrange
        let registry =
          new_registry()
          |> given("I see {string}", ok_step)

        // Act
        let captures_result =
          find_step(registry, gherkin_types.Given, "I see \"Hello World\"")
          |> result.map(fn(m) { m.captures })

        // Assert
        captures_result
        |> should()
        |> be_ok()
        |> equal([CapturedString("Hello World")])
        |> or_fail_with("Should capture string 'Hello World'")
      }),
      it("captures multiple values", fn(_) {
        // Arrange
        let registry =
          new_registry()
          |> given("I add {int} of {string}", ok_step)

        // Act
        let captures_result =
          find_step(registry, gherkin_types.Given, "I add 5 of \"Widget\"")
          |> result.map(fn(m) { m.captures })

        // Assert
        captures_result
        |> should()
        |> be_ok()
        |> equal([CapturedInt(5), CapturedString("Widget")])
        |> or_fail_with("Should capture int and string")
      }),
    ]),
    group("find_step error messages", [
      it("returns descriptive error for undefined step", fn(_) {
        // Arrange
        let registry = new_registry()

        // Act
        let result =
          find_step(registry, gherkin_types.Given, "something undefined")

        // Assert
        result
        |> should()
        |> equal(Error("Undefined step: Given something undefined"))
        |> or_fail_with("Error should include keyword and text")
      }),
    ]),
    group("get_int", [
      it("extracts int at valid index", fn(_) {
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
      it("returns error for non-int at index", fn(_) {
        // Arrange
        let captures = [CapturedString("test")]

        // Act
        let result = get_int(captures, 0)

        // Assert
        result
        |> should()
        |> be_error()
        |> or_fail_with("Should error for non-int")
      }),
      it("returns error for out of bounds index", fn(_) {
        // Arrange
        let captures = [CapturedInt(42)]

        // Act
        let result = get_int(captures, 5)

        // Assert
        result
        |> should()
        |> be_error()
        |> or_fail_with("Should error for out of bounds")
      }),
    ]),
    group("get_float", [
      it("extracts float at valid index", fn(_) {
        // Arrange
        let captures = [CapturedFloat(3.14)]

        // Act
        let ok_result =
          get_float(captures, 0)
          |> result.map(fn(f) { f >. 3.13 && f <. 3.15 })

        // Assert
        ok_result
        |> should()
        |> be_ok()
        |> be_true()
        |> or_fail_with("Should extract float ~3.14")
      }),
      it("returns error for non-float at index", fn(_) {
        // Arrange
        let captures = [CapturedInt(42)]

        // Act
        let result = get_float(captures, 0)

        // Assert
        result
        |> should()
        |> be_error()
        |> or_fail_with("Should error for non-float")
      }),
    ]),
    group("get_string", [
      it("extracts CapturedString at valid index", fn(_) {
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
      it("extracts CapturedWord as string", fn(_) {
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
      it("returns error for non-string at index", fn(_) {
        // Arrange
        let captures = [CapturedInt(42)]

        // Act
        let result = get_string(captures, 0)

        // Assert
        result
        |> should()
        |> be_error()
        |> or_fail_with("Should error for non-string")
      }),
    ]),
    group("get_word", [
      it("extracts CapturedWord at valid index", fn(_) {
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
      it("extracts CapturedString as word", fn(_) {
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
    group("capture_count", [
      it("returns 0 for empty captures", fn(_) {
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
      it("returns correct count for multiple captures", fn(_) {
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
    group("chained registration", [
      it("supports chaining multiple step types", fn(_) {
        // Arrange
        let registry =
          new_registry()
          |> given("a precondition", ok_step)
          |> when_("an action", ok_step)
          |> then_("an outcome", ok_step)

        // Act
        let given_result =
          find_step(registry, gherkin_types.Given, "a precondition")
        let when_result = find_step(registry, gherkin_types.When, "an action")
        let then_result = find_step(registry, gherkin_types.Then, "an outcome")

        // Assert
        let ok_list = [
          result.is_ok(given_result),
          result.is_ok(when_result),
          result.is_ok(then_result),
        ]

        ok_list
        |> should()
        |> equal([True, True, True])
        |> or_fail_with("All step types should be registered")
      }),
    ]),
  ])
}
