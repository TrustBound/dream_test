import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/matchers/collection.{
  be_empty, contain, have_length, not_contain,
}
import dream_test/types.{AssertionFailure, CollectionFailure, MatchFailed}
import dream_test/unit.{describe, it}
import gleam/option.{Some}
import matchers/prior_failure.{prior_failure}

pub fn tests() {
  describe("dream_test/matchers/collection", [
    it("contain passes when the item exists", fn() {
      [1, 2, 3]
      |> should
      |> contain(2)
      |> or_fail_with("list should contain 2")
    }),

    it("not_contain passes when the item does not exist", fn() {
      [1, 2, 3]
      |> should
      |> not_contain(4)
      |> or_fail_with("list should not contain 4")
    }),

    it("have_length passes when the length matches", fn() {
      [1, 2, 3]
      |> should
      |> have_length(3)
      |> or_fail_with("list should have length 3")
    }),

    it("be_empty passes for an empty list", fn() {
      []
      |> should
      |> be_empty()
      |> or_fail_with("empty list should be empty")
    }),

    it("contain reports the list and the missing item", fn() {
      [1, 2, 3]
      |> should
      |> contain(4)
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "contain",
          message: "",
          payload: Some(CollectionFailure(
            actual: "[1, 2, 3]",
            expected: "4",
            operation: "contain",
          )),
        )),
      )
      |> or_fail_with("contain should report the failure")
    }),

    it("contain passes an earlier failure through", fn() {
      prior_failure()
      |> contain(1)
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("contain should keep the earlier failure")
    }),

    it("not_contain reports the list and the unwanted item", fn() {
      [1, 2, 3]
      |> should
      |> not_contain(2)
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "not_contain",
          message: "",
          payload: Some(CollectionFailure(
            actual: "[1, 2, 3]",
            expected: "not 2",
            operation: "not_contain",
          )),
        )),
      )
      |> or_fail_with("not_contain should report the failure")
    }),

    it("not_contain passes an earlier failure through", fn() {
      prior_failure()
      |> not_contain(1)
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("not_contain should keep the earlier failure")
    }),

    it("have_length reports both lengths when they differ", fn() {
      [1, 2, 3]
      |> should
      |> have_length(2)
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "have_length",
          message: "",
          payload: Some(CollectionFailure(
            actual: "list with length 3",
            expected: "list with length 2",
            operation: "have_length",
          )),
        )),
      )
      |> or_fail_with("have_length should report the failure")
    }),

    it("have_length passes an earlier failure through", fn() {
      prior_failure()
      |> have_length(1)
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("have_length should keep the earlier failure")
    }),

    it("be_empty reports a list that has items", fn() {
      [1]
      |> should
      |> be_empty()
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_empty",
          message: "",
          payload: Some(CollectionFailure(
            actual: "[1]",
            expected: "[]",
            operation: "be_empty",
          )),
        )),
      )
      |> or_fail_with("be_empty should report the failure")
    }),

    it("be_empty passes an earlier failure through", fn() {
      prior_failure()
      |> be_empty()
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("be_empty should keep the earlier failure")
    }),
  ])
}
