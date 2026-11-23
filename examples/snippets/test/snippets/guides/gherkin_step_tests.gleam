import dream_test/gherkin/step_trie.{CapturedInt, CapturedWord}
import dream_test/gherkin/steps.{StepContext}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{None}
import snippets/guides/gherkin_cart_steps.{add_items, cart_steps}

fn context_with(captures) {
  StepContext(
    captures: captures,
    table: None,
    doc_string: None,
    scenario_id: "Shopping Cart::Adding items#1",
  )
}

pub fn tests() {
  describe("The cart steps", [
    it("have no duplicate definition", fn() {
      // Act
      let problems = steps.validate(cart_steps())

      // Assert
      problems
      |> should
      |> be_equal(Ok(Nil))
      |> or_fail_with("each pattern should have one definition per phase")
    }),
    it("add the captured number of items", fn() {
      // Act
      let cart = add_items(3, context_with([CapturedInt(2)]))

      // Assert
      cart
      |> should
      |> be_equal(Ok(5))
      |> or_fail_with("3 items and 2 more should be 5")
    }),
    it("fail on a capture that is not a number", fn() {
      // Act
      let cart = add_items(3, context_with([CapturedWord("two")]))

      // Assert
      cart
      |> should
      |> be_equal(Error("Capture 0 is the word \"two\", not an integer"))
      |> or_fail_with("a word should not count as items")
    }),
  ])
}
