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
  ])
}

fn steps_test_handler(
  _context: steps.StepContext,
) -> Result(test_types.AssertionResult, String) {
  Ok(test_types.AssertionOk)
}
