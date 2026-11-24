import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import snippets/doc/matchers/equality/be_equal as be_equal_example
import snippets/doc/matchers/equality/not_equal

pub fn tests() {
  describe("Doc examples: matchers/equality", [
    it("sum_equals_five passes", fn() {
      // Act
      let result = be_equal_example.sum_equals_five()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected sum_equals_five to pass")
    }),
    it("sum_does_not_equal_three passes", fn() {
      // Act
      let result = not_equal.sum_does_not_equal_three()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected sum_does_not_equal_three to pass")
    }),
  ])
}
