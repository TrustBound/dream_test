import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import snippets/doc/matchers/result/be_error
import snippets/doc/matchers/result/be_ok

pub fn tests() {
  describe("Doc examples: matchers/result", [
    it("ok_holds_hello passes", fn() {
      // Act
      let result = be_ok.ok_holds_hello()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected ok_holds_hello to pass")
    }),
    it("error_holds_nope passes", fn() {
      // Act
      let result = be_error.error_holds_nope()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected error_holds_nope to pass")
    }),
  ])
}
