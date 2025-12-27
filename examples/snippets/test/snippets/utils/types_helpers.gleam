import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/option.{None}

pub fn tests() {
  describe("Types", [
    it("status_from_failures returns Passed for empty failures", fn() {
      types.status_from_failures([])
      |> should
      |> be_equal(types.Passed)
      |> or_fail_with("expected Passed for empty failures")
    }),

    it("to_assertion_result converts match results", fn() {
      types.to_assertion_result(types.MatchOk(1))
      |> should
      |> be_equal(types.AssertionOk)
      |> or_fail_with("expected MatchOk -> AssertionOk")
    }),

    it("status_from_failures returns Failed for non-empty failures", fn() {
      let failure =
        types.AssertionFailure(operator: "op", message: "msg", payload: None)

      types.status_from_failures([failure])
      |> should
      |> be_equal(types.Failed)
      |> or_fail_with("expected Failed for non-empty failures")
    }),
  ])
}
