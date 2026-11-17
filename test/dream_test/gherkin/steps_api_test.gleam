import dream_test/gherkin/step_trie
import dream_test/gherkin/steps
import dream_test/gherkin/types as gtypes
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should}
import dream_test/types as test_types
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("dream_test/gherkin/steps", [
    it("find_step captures two values for {int} and {word}", fn() {
      // Arrange
      let registry =
        steps.new()
        |> steps.given("I have {int} items of {word}", steps_test_handler)

      // Act
      let result =
        steps.find_step(registry, gtypes.Given, "I have 3 items of apples")

      // Assert
      case result {
        Ok(step_trie.StepMatch(_handler, captures)) ->
          steps.capture_count(captures)
          |> should
          |> be_equal(2)
          |> or_fail_with("should have 2 captures")
        Error(msg) -> Ok(fail_with(msg))
      }
    }),

    it("get_int extracts captured {int}", fn() {
      // Arrange
      let registry =
        steps.new()
        |> steps.given("I have {int} items of {word}", steps_test_handler)

      // Act
      let result =
        steps.find_step(registry, gtypes.Given, "I have 3 items of apples")

      // Assert
      case result {
        Ok(step_trie.StepMatch(_handler, captures)) ->
          steps.get_int(captures, 0)
          |> should
          |> be_equal(Ok(3))
          |> or_fail_with("first capture should be int 3")
        Error(msg) -> Ok(fail_with(msg))
      }
    }),

    it("get_word extracts captured {word}", fn() {
      // Arrange
      let registry =
        steps.new()
        |> steps.given("I have {int} items of {word}", steps_test_handler)

      // Act
      let result =
        steps.find_step(registry, gtypes.Given, "I have 3 items of apples")

      // Assert
      case result {
        Ok(step_trie.StepMatch(_handler, captures)) ->
          steps.get_word(captures, 1)
          |> should
          |> be_equal(Ok("apples"))
          |> or_fail_with("second capture should be word apples")
        Error(msg) -> Ok(fail_with(msg))
      }
    }),

    it("get_string extracts {string} without quotes", fn() {
      // Arrange
      let registry =
        steps.new()
        |> steps.given("I say {string}", steps_test_handler)

      // Act
      let result = steps.find_step(registry, gtypes.Given, "I say \"hello\"")

      // Assert
      case result {
        Ok(step_trie.StepMatch(_handler, captures)) ->
          steps.get_string(captures, 0)
          |> should
          |> be_equal(Ok("hello"))
          |> or_fail_with("string capture should be unquoted")
        Error(msg) -> Ok(fail_with(msg))
      }
    }),

    it("find_step returns Error for undefined steps", fn() {
      let registry = steps.new()
      case steps.find_step(registry, gtypes.Given, "I do not exist") {
        Ok(_) -> Ok(fail_with("expected undefined step error"))
        Error(_msg) -> Ok(test_types.AssertionOk)
      }
    }),

    it("get_int returns Error when capture index is out of bounds", fn() {
      let result = steps.get_int([], 0)
      case result {
        Ok(_) -> Ok(fail_with("expected Error for missing capture"))
        Error(_msg) -> Ok(test_types.AssertionOk)
      }
    }),

    it("find_step names an And step in the undefined step error", fn() {
      steps.find_step(steps.new(), gtypes.And, "x")
      |> should
      |> be_equal(Error("Undefined step: And x"))
      |> or_fail_with("the error should name the And keyword")
    }),

    it("find_step names a But step in the undefined step error", fn() {
      steps.find_step(steps.new(), gtypes.But, "x")
      |> should
      |> be_equal(Error("Undefined step: But x"))
      |> or_fail_with("the error should name the But keyword")
    }),

    it("find_step names a When step in the undefined step error", fn() {
      steps.find_step(steps.new(), gtypes.When, "x")
      |> should
      |> be_equal(Error("Undefined step: When x"))
      |> or_fail_with("the error should name the When keyword")
    }),

    it("get_int returns Error for a capture that is not an int", fn() {
      steps.get_int([step_trie.CapturedWord("a")], 0)
      |> should
      |> be_equal(Error("Capture at index is not an integer"))
      |> or_fail_with("a word is not an int")
    }),

    it("get_float extracts a captured float", fn() {
      steps.get_float([step_trie.CapturedFloat(1.5)], 0)
      |> should
      |> be_equal(Ok(1.5))
      |> or_fail_with("the float should come back")
    }),

    it("get_float returns Error for a capture that is not a float", fn() {
      steps.get_float([step_trie.CapturedInt(1)], 0)
      |> should
      |> be_equal(Error("Capture at index is not a float"))
      |> or_fail_with("an int is not a float")
    }),

    it("get_float returns Error when capture index is out of bounds", fn() {
      steps.get_float([], 0)
      |> should
      |> be_equal(Error("No capture at index"))
      |> or_fail_with("an empty list has no capture")
    }),

    it("get_string accepts a captured word", fn() {
      steps.get_string([step_trie.CapturedWord("w")], 0)
      |> should
      |> be_equal(Ok("w"))
      |> or_fail_with("a word should count as a string")
    }),

    it("get_string returns Error for a capture that is not a string", fn() {
      steps.get_string([step_trie.CapturedInt(1)], 0)
      |> should
      |> be_equal(Error("Capture at index is not a string"))
      |> or_fail_with("an int is not a string")
    }),

    it("get_string returns Error when capture index is out of bounds", fn() {
      steps.get_string([], 0)
      |> should
      |> be_equal(Error("No capture at index"))
      |> or_fail_with("an empty list has no capture")
    }),

    it("get_word accepts a captured string", fn() {
      steps.get_word([step_trie.CapturedString("s")], 0)
      |> should
      |> be_equal(Ok("s"))
      |> or_fail_with("a string should count as a word")
    }),

    it("get_word returns Error for a capture that is not a word", fn() {
      steps.get_word([step_trie.CapturedInt(1)], 0)
      |> should
      |> be_equal(Error("Capture at index is not a word"))
      |> or_fail_with("an int is not a word")
    }),

    it("get_word returns Error when capture index is out of bounds", fn() {
      steps.get_word([], 0)
      |> should
      |> be_equal(Error("No capture at index"))
      |> or_fail_with("an empty list has no capture")
    }),
  ])
}

fn steps_test_handler(
  _context: steps.StepContext,
) -> Result(test_types.AssertionResult, String) {
  Ok(test_types.AssertionOk)
}
