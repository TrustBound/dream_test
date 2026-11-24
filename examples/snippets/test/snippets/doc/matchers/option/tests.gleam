import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import snippets/doc/matchers/option/be_none
import snippets/doc/matchers/option/be_some

pub fn tests() {
  describe("Doc examples: matchers/option", [
    it("some_holds_forty_two passes", fn() {
      // Act
      let result = be_some.some_holds_forty_two()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected some_holds_forty_two to pass")
    }),
    it("none_is_empty passes", fn() {
      // Act
      let result = be_none.none_is_empty()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected none_is_empty to pass")
    }),
  ])
}
