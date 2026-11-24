import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import snippets/doc/matchers/collection/be_empty
import snippets/doc/matchers/collection/contain
import snippets/doc/matchers/collection/have_length
import snippets/doc/matchers/collection/not_contain

pub fn tests() {
  describe("Doc examples: matchers/collection", [
    it("list_contains_two passes", fn() {
      // Act
      let result = contain.list_contains_two()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected list_contains_two to pass")
    }),
    it("list_does_not_contain_d passes", fn() {
      // Act
      let result = not_contain.list_does_not_contain_d()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected list_does_not_contain_d to pass")
    }),
    it("list_has_three_items passes", fn() {
      // Act
      let result = have_length.list_has_three_items()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected list_has_three_items to pass")
    }),
    it("list_is_empty passes", fn() {
      // Act
      let result = be_empty.list_is_empty()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected list_is_empty to pass")
    }),
  ])
}
