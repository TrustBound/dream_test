import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import snippets/doc/matchers/boolean/be_false
import snippets/doc/matchers/boolean/be_true

pub fn tests() {
  describe("Doc examples: matchers/boolean", [
    it("true_is_true passes", fn() {
      // Act
      let result = be_true.true_is_true()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected true_is_true to pass")
    }),
    it("false_is_false passes", fn() {
      // Act
      let result = be_false.false_is_false()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected false_is_false to pass")
    }),
  ])
}
