import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/matchers/boolean
import dream_test/types.{AssertionFailure, BooleanFailure, MatchFailed}
import dream_test/unit.{describe, it}
import gleam/option.{Some}
import matchers/prior_failure.{prior_failure}

pub fn tests() {
  describe("dream_test/matchers/boolean", [
    it("be_true passes for True", fn() {
      True
      |> should
      |> boolean.be_true()
      |> or_fail_with("True should be true")
    }),

    it("be_true reports a BooleanFailure for False", fn() {
      False
      |> should
      |> boolean.be_true()
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_true",
          message: "",
          payload: Some(BooleanFailure(actual: False, expected: True)),
        )),
      )
      |> or_fail_with("be_true should fail for False")
    }),

    it("be_true passes an earlier failure through", fn() {
      prior_failure()
      |> boolean.be_true()
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("be_true should keep the earlier failure")
    }),

    it("be_false passes for False", fn() {
      False
      |> should
      |> boolean.be_false()
      |> or_fail_with("False should be false")
    }),

    it("be_false reports a BooleanFailure for True", fn() {
      True
      |> should
      |> boolean.be_false()
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_false",
          message: "",
          payload: Some(BooleanFailure(actual: True, expected: False)),
        )),
      )
      |> or_fail_with("be_false should fail for True")
    }),

    it("be_false passes an earlier failure through", fn() {
      prior_failure()
      |> boolean.be_false()
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("be_false should keep the earlier failure")
    }),
  ])
}
