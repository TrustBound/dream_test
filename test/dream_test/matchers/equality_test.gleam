import dream_test/matchers.{or_fail_with, should}
import dream_test/matchers/equality
import dream_test/types.{AssertionFailure, EqualityFailure, MatchFailed}
import dream_test/unit.{describe, it}
import gleam/option.{Some}
import matchers/prior_failure.{prior_failure}

pub fn tests() {
  describe("dream_test/matchers/equality", [
    it("equal passes for equal values", fn() {
      1
      |> should
      |> equality.be_equal(1)
      |> or_fail_with("1 should equal 1")
    }),

    it("be_equal reports both values when they differ", fn() {
      "actual"
      |> should
      |> equality.be_equal("expected")
      |> should
      |> equality.be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_equal",
          message: "",
          payload: Some(EqualityFailure(
            actual: "\"actual\"",
            expected: "\"expected\"",
          )),
        )),
      )
      |> or_fail_with("be_equal should fail with both inspected values")
    }),

    it("be_equal passes an earlier failure through", fn() {
      prior_failure()
      |> equality.be_equal(1)
      |> should
      |> equality.be_equal(prior_failure())
      |> or_fail_with("be_equal should keep the earlier failure")
    }),

    it("not_equal passes for different values", fn() {
      1
      |> should
      |> equality.not_equal(2)
      |> or_fail_with("1 should not equal 2")
    }),

    it("not_equal reports the value when both are equal", fn() {
      [1, 2]
      |> should
      |> equality.not_equal([1, 2])
      |> should
      |> equality.be_equal(
        MatchFailed(AssertionFailure(
          operator: "not_equal",
          message: "",
          payload: Some(EqualityFailure(
            actual: "[1, 2]",
            expected: "not [1, 2]",
          )),
        )),
      )
      |> or_fail_with("not_equal should fail for equal values")
    }),

    it("not_equal passes an earlier failure through", fn() {
      prior_failure()
      |> equality.not_equal(1)
      |> should
      |> equality.be_equal(prior_failure())
      |> or_fail_with("not_equal should keep the earlier failure")
    }),
  ])
}
