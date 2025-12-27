import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionFailure}
import dream_test/unit.{describe, it}
import gleam/option.{None}

pub fn tests() {
  describe("dream_test/context", [
    it("new has no failures", fn() {
      context.new()
      |> context.failures()
      |> should
      |> be_equal([])
      |> or_fail_with("expected new context to have no failures")
    }),

    it("add_failure stores failures newest-first", fn() {
      let first_failure =
        AssertionFailure(operator: "op1", message: "m1", payload: None)
      let second_failure =
        AssertionFailure(operator: "op2", message: "m2", payload: None)

      context.new()
      |> context.add_failure(first_failure)
      |> context.add_failure(second_failure)
      |> context.failures()
      |> should
      |> be_equal([second_failure, first_failure])
      |> or_fail_with("expected newest-first failure ordering")
    }),
  ])
}
