import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/matchers/comparison
import dream_test/types.{AssertionFailure, ComparisonFailure, MatchFailed}
import dream_test/unit.{describe, it}
import gleam/option.{Some}
import matchers/prior_failure.{prior_failure}

pub fn tests() {
  describe("dream_test/matchers/comparison", [
    it("be_greater_than passes for greater values", fn() {
      5
      |> should
      |> comparison.be_greater_than(3)
      |> or_fail_with("5 should be > 3")
    }),

    it("be_less_than passes for lesser values", fn() {
      5
      |> should
      |> comparison.be_less_than(10)
      |> or_fail_with("5 should be < 10")
    }),

    it("be_at_least passes for equal values", fn() {
      5
      |> should
      |> comparison.be_at_least(5)
      |> or_fail_with("5 should be >= 5")
    }),

    it("be_at_most passes for equal values", fn() {
      5
      |> should
      |> comparison.be_at_most(5)
      |> or_fail_with("5 should be <= 5")
    }),

    it("be_between passes for values inside inclusive bounds", fn() {
      5
      |> should
      |> comparison.be_between(1, 10)
      |> or_fail_with("5 should be between 1 and 10")
    }),

    it("be_in_range passes for values inside range", fn() {
      5
      |> should
      |> comparison.be_in_range(5, 6)
      |> or_fail_with("5 should be in range [5,6]")
    }),

    it("be_greater_than_float passes for greater float values", fn() {
      1.5
      |> should
      |> comparison.be_greater_than_float(1.0)
      |> or_fail_with("1.5 should be > 1.0")
    }),

    it("be_less_than_float passes for lesser float values", fn() {
      1.5
      |> should
      |> comparison.be_less_than_float(2.0)
      |> or_fail_with("1.5 should be < 2.0")
    }),

    it("be_greater_than reports a value that is not greater", fn() {
      5
      |> should
      |> comparison.be_greater_than(5)
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_greater_than",
          message: "",
          payload: Some(ComparisonFailure(
            actual: "5",
            expected: "> 5",
            operator: "be_greater_than",
          )),
        )),
      )
      |> or_fail_with("be_greater_than should report the failure")
    }),

    it("be_greater_than passes an earlier failure through", fn() {
      prior_failure()
      |> comparison.be_greater_than(5)
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("be_greater_than should keep the earlier failure")
    }),

    it("be_less_than reports a value that is not less", fn() {
      5
      |> should
      |> comparison.be_less_than(5)
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_less_than",
          message: "",
          payload: Some(ComparisonFailure(
            actual: "5",
            expected: "< 5",
            operator: "be_less_than",
          )),
        )),
      )
      |> or_fail_with("be_less_than should report the failure")
    }),

    it("be_less_than passes an earlier failure through", fn() {
      prior_failure()
      |> comparison.be_less_than(5)
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("be_less_than should keep the earlier failure")
    }),

    it("be_at_least reports a value below the minimum", fn() {
      4
      |> should
      |> comparison.be_at_least(5)
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_at_least",
          message: "",
          payload: Some(ComparisonFailure(
            actual: "4",
            expected: ">= 5",
            operator: "be_at_least",
          )),
        )),
      )
      |> or_fail_with("be_at_least should report the failure")
    }),

    it("be_at_least passes an earlier failure through", fn() {
      prior_failure()
      |> comparison.be_at_least(5)
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("be_at_least should keep the earlier failure")
    }),

    it("be_at_most reports a value above the maximum", fn() {
      6
      |> should
      |> comparison.be_at_most(5)
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_at_most",
          message: "",
          payload: Some(ComparisonFailure(
            actual: "6",
            expected: "<= 5",
            operator: "be_at_most",
          )),
        )),
      )
      |> or_fail_with("be_at_most should report the failure")
    }),

    it("be_at_most passes an earlier failure through", fn() {
      prior_failure()
      |> comparison.be_at_most(5)
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("be_at_most should keep the earlier failure")
    }),

    it("be_between reports a value on the lower bound", fn() {
      1
      |> should
      |> comparison.be_between(1, 10)
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_between",
          message: "",
          payload: Some(ComparisonFailure(
            actual: "1",
            expected: "1 < value < 10",
            operator: "be_between",
          )),
        )),
      )
      |> or_fail_with("be_between should report the failure")
    }),

    it("be_between passes an earlier failure through", fn() {
      prior_failure()
      |> comparison.be_between(1, 10)
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("be_between should keep the earlier failure")
    }),

    it("be_in_range reports a value above the range", fn() {
      11
      |> should
      |> comparison.be_in_range(1, 10)
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_in_range",
          message: "",
          payload: Some(ComparisonFailure(
            actual: "11",
            expected: "1 <= value <= 10",
            operator: "be_in_range",
          )),
        )),
      )
      |> or_fail_with("be_in_range should report the failure")
    }),

    it("be_in_range passes an earlier failure through", fn() {
      prior_failure()
      |> comparison.be_in_range(1, 10)
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("be_in_range should keep the earlier failure")
    }),

    it("be_greater_than_float reports a value that is not greater", fn() {
      1.5
      |> should
      |> comparison.be_greater_than_float(1.5)
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_greater_than_float",
          message: "",
          payload: Some(ComparisonFailure(
            actual: "1.5",
            expected: "> 1.5",
            operator: "be_greater_than_float",
          )),
        )),
      )
      |> or_fail_with("be_greater_than_float should report the failure")
    }),

    it("be_greater_than_float passes an earlier failure through", fn() {
      prior_failure()
      |> comparison.be_greater_than_float(1.5)
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("be_greater_than_float should keep the earlier failure")
    }),

    it("be_less_than_float reports a value that is not less", fn() {
      1.5
      |> should
      |> comparison.be_less_than_float(1.5)
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_less_than_float",
          message: "",
          payload: Some(ComparisonFailure(
            actual: "1.5",
            expected: "< 1.5",
            operator: "be_less_than_float",
          )),
        )),
      )
      |> or_fail_with("be_less_than_float should report the failure")
    }),

    it("be_less_than_float passes an earlier failure through", fn() {
      prior_failure()
      |> comparison.be_less_than_float(1.5)
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("be_less_than_float should keep the earlier failure")
    }),
  ])
}
