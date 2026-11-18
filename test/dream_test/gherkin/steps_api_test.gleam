import dream_test/gherkin/step_trie
import dream_test/gherkin/steps
import dream_test/gherkin/types as gtypes
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should}
import dream_test/types as test_types
import dream_test/unit.{describe, it}
import gleam/result

pub fn tests() {
  describe("dream_test/gherkin/steps", [
    it("find_step captures two values for {int} and {word}", fn() {
      // Arrange
      let registry =
        steps.new(initial: Nil)
        |> steps.given("I have {int} items of {word}", steps_test_action)

      // Act
      let result =
        steps.find_step(registry, gtypes.GivenPhase, "I have 3 items of apples")

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
        steps.new(initial: Nil)
        |> steps.given("I have {int} items of {word}", steps_test_action)

      // Act
      let result =
        steps.find_step(registry, gtypes.GivenPhase, "I have 3 items of apples")

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
        steps.new(initial: Nil)
        |> steps.given("I have {int} items of {word}", steps_test_action)

      // Act
      let result =
        steps.find_step(registry, gtypes.GivenPhase, "I have 3 items of apples")

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
        steps.new(initial: Nil)
        |> steps.given("I say {string}", steps_test_action)

      // Act
      let result =
        steps.find_step(registry, gtypes.GivenPhase, "I say \"hello\"")

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

    it("initial_state gives the state that new got", fn() {
      steps.new(initial: 7)
      |> steps.initial_state
      |> should
      |> be_equal(7)
      |> or_fail_with("the registry should keep the initial state")
    }),

    it("find_step returns Error for undefined steps", fn() {
      let registry = steps.new(initial: Nil)
      case steps.find_step(registry, gtypes.GivenPhase, "I do not exist") {
        Ok(_) -> Ok(fail_with("expected undefined step error"))
        Error(_msg) -> Ok(test_types.AssertionOk)
      }
    }),

    it("get_int returns Error when capture index is out of bounds", fn() {
      steps.get_int([], 0)
      |> should
      |> be_equal(Error("No capture at index 0: the step has no captures"))
      |> or_fail_with("an empty list has no capture")
    }),

    it("get_int names the one capture a step has", fn() {
      steps.get_int([step_trie.CapturedInt(1)], 1)
      |> should
      |> be_equal(Error("No capture at index 1: the step has 1 capture"))
      |> or_fail_with("the error should give the capture count")
    }),

    it("get_int names the number of captures a step has", fn() {
      steps.get_int([step_trie.CapturedInt(1), step_trie.CapturedInt(2)], 2)
      |> should
      |> be_equal(Error("No capture at index 2: the step has 2 captures"))
      |> or_fail_with("the error should give the capture count")
    }),

    it("get_int names a captured float in its Error", fn() {
      steps.get_int([step_trie.CapturedFloat(2.5)], 0)
      |> should
      |> be_equal(Error("Capture 0 is the float 2.5, not an integer"))
      |> or_fail_with("the error should show the float")
    }),

    it("get_int names a captured string in its Error", fn() {
      steps.get_int([step_trie.CapturedString("s")], 0)
      |> should
      |> be_equal(Error("Capture 0 is the string \"s\", not an integer"))
      |> or_fail_with("the error should show the string")
    }),

    it("find_step names a Then step in the undefined step error", fn() {
      steps.find_step(steps.new(initial: Nil), gtypes.ThenPhase, "x")
      |> should
      |> be_equal(Error("Undefined step: Then x"))
      |> or_fail_with("the error should name the Then phase")
    }),

    it("find_step names a When step in the undefined step error", fn() {
      steps.find_step(steps.new(initial: Nil), gtypes.WhenPhase, "x")
      |> should
      |> be_equal(Error("Undefined step: When x"))
      |> or_fail_with("the error should name the When phase")
    }),

    it("find_step does not match a definition of another phase", fn() {
      steps.new(initial: Nil)
      |> steps.given("a b", steps_test_action)
      |> steps.find_step(gtypes.ThenPhase, "a b")
      |> result.map(capture_count_of)
      |> should
      |> be_equal(Error("Undefined step: Then a b"))
      |> or_fail_with("a Given definition should not match a Then step")
    }),

    it("find_step returns the duplicate step definition error", fn() {
      steps.new(initial: Nil)
      |> steps.given("a b", steps_test_action)
      |> steps.given("a b", steps_test_action)
      |> steps.find_step(gtypes.GivenPhase, "a b")
      |> result.map(capture_count_of)
      |> should
      |> be_equal(Error(
        "Duplicate step definition: Given \"a b\" is already defined. Each pattern can have one definition for each of Given, When and Then.",
      ))
      |> or_fail_with("a duplicate should make find_step fail")
    }),

    it("find_step gives a Given definition as an action", fn() {
      steps.new(initial: Nil)
      |> steps.given("a b", steps_test_action)
      |> steps.find_step(gtypes.GivenPhase, "a b")
      |> result.map(definition_kind)
      |> should
      |> be_equal(Ok("action"))
      |> or_fail_with("a Given definition should be an action")
    }),

    it("find_step gives a When definition as an action", fn() {
      steps.new(initial: Nil)
      |> steps.when("a b", steps_test_action)
      |> steps.find_step(gtypes.WhenPhase, "a b")
      |> result.map(definition_kind)
      |> should
      |> be_equal(Ok("action"))
      |> or_fail_with("a When definition should be an action")
    }),

    it("find_step gives a Then definition as a check", fn() {
      steps.new(initial: Nil)
      |> steps.then("a b", steps_test_check)
      |> steps.find_step(gtypes.ThenPhase, "a b")
      |> result.map(definition_kind)
      |> should
      |> be_equal(Ok("check"))
      |> or_fail_with("a Then definition should be a check")
    }),

    it("validate returns Ok for a registry without duplicates", fn() {
      steps.new(initial: Nil)
      |> steps.given("a b", steps_test_action)
      |> steps.when("a b", steps_test_action)
      |> steps.then("a b", steps_test_check)
      |> steps.validate
      |> should
      |> be_equal(Ok(Nil))
      |> or_fail_with("one pattern in three phases is not a duplicate")
    }),

    it("validate gives one line for each duplicate in registration order", fn() {
      steps.new(initial: Nil)
      |> steps.given("a b", steps_test_action)
      |> steps.given("a b", steps_test_action)
      |> steps.then("c", steps_test_check)
      |> steps.then("c", steps_test_check)
      |> steps.validate
      |> should
      |> be_equal(Error(
        "Duplicate step definition: Given \"a b\" is already defined. Each pattern can have one definition for each of Given, When and Then.\nDuplicate step definition: Then \"c\" is already defined. Each pattern can have one definition for each of Given, When and Then.",
      ))
      |> or_fail_with("each duplicate should have its own line")
    }),

    it("get_int returns Error for a capture that is not an int", fn() {
      steps.get_int([step_trie.CapturedWord("a")], 0)
      |> should
      |> be_equal(Error("Capture 0 is the word \"a\", not an integer"))
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
      |> be_equal(Error("Capture 0 is the integer 1, not a float"))
      |> or_fail_with("an int is not a float")
    }),

    it("get_float returns Error when capture index is out of bounds", fn() {
      steps.get_float([], 0)
      |> should
      |> be_equal(Error("No capture at index 0: the step has no captures"))
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
      |> be_equal(Error("Capture 0 is the integer 1, not a string"))
      |> or_fail_with("an int is not a string")
    }),

    it("get_string returns Error when capture index is out of bounds", fn() {
      steps.get_string([], 0)
      |> should
      |> be_equal(Error("No capture at index 0: the step has no captures"))
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
      |> be_equal(Error("Capture 0 is the integer 1, not a word"))
      |> or_fail_with("an int is not a word")
    }),

    it("get_word returns Error when capture index is out of bounds", fn() {
      steps.get_word([], 0)
      |> should
      |> be_equal(Error("No capture at index 0: the step has no captures"))
      |> or_fail_with("an empty list has no capture")
    }),
  ])
}

fn steps_test_action(
  state: Nil,
  _context: steps.StepContext,
) -> Result(Nil, String) {
  Ok(state)
}

fn steps_test_check(
  _state: Nil,
  _context: steps.StepContext,
) -> Result(test_types.AssertionResult, String) {
  Ok(test_types.AssertionOk)
}

fn definition_kind(
  matched: step_trie.StepMatch(steps.StepDefinition(Nil)),
) -> String {
  case matched.handler {
    steps.Action(_) -> "action"
    steps.Check(_) -> "check"
  }
}

fn capture_count_of(
  matched: step_trie.StepMatch(steps.StepDefinition(Nil)),
) -> Int {
  steps.capture_count(matched.captures)
}
