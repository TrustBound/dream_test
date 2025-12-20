//// README: TestContext helpers (internal)
////
//// This snippet exists so hexdocs examples for `dream_test/context` can be
//// copied from real, compiled code.

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
      let f1 = AssertionFailure(operator: "op1", message: "m1", payload: None)
      let f2 = AssertionFailure(operator: "op2", message: "m2", payload: None)

      context.new()
      |> context.add_failure(f1)
      |> context.add_failure(f2)
      |> context.failures()
      |> should
      |> be_equal([f2, f1])
      |> or_fail_with("expected newest-first failure ordering")
    }),
  ])
}
