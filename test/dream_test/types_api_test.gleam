import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/option.{None}

pub fn tests() {
  describe("dream_test/types", [
    it("to_assertion_result converts match results to assertion results", fn() {
      types.to_assertion_result(types.MatchOk(1))
      |> should
      |> be_equal(types.AssertionOk)
      |> or_fail_with("MatchOk should map to AssertionOk")
    }),

    it("to_assertion_result preserves failures", fn() {
      let failure =
        types.AssertionFailure(operator: "op", message: "msg", payload: None)

      types.to_assertion_result(types.MatchFailed(failure))
      |> should
      |> be_equal(types.AssertionFailed(failure))
      |> or_fail_with("MatchFailed should map to AssertionFailed(failure)")
    }),

    it("root builds a Root with a top-level Group", fn() {
      let suite = types.root("r", Nil, [])
      let types.Root(seed: seed, tree: _tree) = suite

      seed
      |> should
      |> be_equal(Nil)
      |> or_fail_with("seed should be preserved")
    }),

    it("root creates a top-level Group node", fn() {
      let suite = types.root("r", Nil, [])
      let types.Root(seed: _, tree: tree) = suite

      tree
      |> should
      |> be_equal(types.Group(name: "r", tags: [], children: []))
      |> or_fail_with(
        "expected Root(tree: Group(name: \"r\", tags: [], children: []))",
      )
    }),

    it("status_from_failures returns Passed for empty failures", fn() {
      types.status_from_failures([])
      |> should
      |> be_equal(types.Passed)
      |> or_fail_with("empty failures should be Passed")
    }),

    it("status_from_failures returns Failed for non-empty failures", fn() {
      let failure =
        types.AssertionFailure(operator: "op", message: "msg", payload: None)

      types.status_from_failures([failure])
      |> should
      |> be_equal(types.Failed)
      |> or_fail_with("non-empty failures should be Failed")
    }),
  ])
}
