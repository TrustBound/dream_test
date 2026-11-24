import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import snippets/doc/matchers/fail_with

pub fn tests() {
  describe("Doc examples: matchers", [
    it("one_plus_one_is_two passes", fn() {
      // Act
      let result = fail_with.one_plus_one_is_two()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected one_plus_one_is_two to pass")
    }),
  ])
}
