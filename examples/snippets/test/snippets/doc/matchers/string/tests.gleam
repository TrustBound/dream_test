import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import snippets/doc/matchers/string/contain_string
import snippets/doc/matchers/string/end_with
import snippets/doc/matchers/string/match_regex
import snippets/doc/matchers/string/start_with

pub fn tests() {
  describe("Doc examples: matchers/string", [
    it("greeting_starts_with_hello passes", fn() {
      // Act
      let result = start_with.greeting_starts_with_hello()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected greeting_starts_with_hello to pass")
    }),
    it("file_name_ends_with_gleam passes", fn() {
      // Act
      let result = end_with.file_name_ends_with_gleam()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected file_name_ends_with_gleam to pass")
    }),
    it("greeting_contains_world passes", fn() {
      // Act
      let result = contain_string.greeting_contains_world()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected greeting_contains_world to pass")
    }),
    it("identifier_matches_pattern passes", fn() {
      // Act
      let result = match_regex.identifier_matches_pattern()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected identifier_matches_pattern to pass")
    }),
  ])
}
