import dream_test/gherkin/step_trie.{CapturedInt, StepMatch}
import dream_test/gherkin/types.{GivenPhase} as _
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import gleam/option.{Some}
import gleam/result
import snippets/doc/gherkin/step_trie/insert
import snippets/doc/gherkin/step_trie/lookup
import snippets/doc/gherkin/step_trie/new
import snippets/doc/gherkin/step_trie/parse_step_pattern
import snippets/doc/gherkin/step_trie/tokenize_step_text

pub fn tests() {
  describe("Doc examples: gherkin/step_trie", [
    it("total_usd_captures_a_float passes", fn() {
      // Act
      let result = lookup.total_usd_captures_a_float()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected total_usd_captures_a_float to give the documented result",
      )
    }),
    it("float_with_prefix_and_suffix_splits_into_segments passes", fn() {
      // Act
      let result =
        parse_step_pattern.float_with_prefix_and_suffix_splits_into_segments()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected float_with_prefix_and_suffix_splits_into_segments to give the documented result",
      )
    }),
    it("quoted_run_stays_one_word passes", fn() {
      // Act
      let result = tokenize_step_text.quoted_run_stays_one_word()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected quoted_run_stays_one_word to give the documented result",
      )
    }),
    it("empty_cart_trie matches its own text", fn() {
      // Act
      let result =
        new.empty_cart_trie()
        |> result.map(fn(trie) {
          step_trie.lookup(trie, GivenPhase, "I have an empty cart")
        })

      // Assert
      result
      |> should
      |> be_equal(Ok(Some(StepMatch(handler: "empty", captures: []))))
      |> or_fail_with("expected empty_cart_trie to give the documented result")
    }),
    it("item_count_trie captures the count", fn() {
      // Act
      let result =
        insert.item_count_trie()
        |> result.map(fn(trie) {
          step_trie.lookup(trie, GivenPhase, "I have 3 items")
        })

      // Assert
      result
      |> should
      |> be_equal(
        Ok(Some(StepMatch(handler: "count", captures: [CapturedInt(3)]))),
      )
      |> or_fail_with("expected item_count_trie to give the documented result")
    }),
  ])
}
