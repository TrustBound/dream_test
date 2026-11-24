import dream_test/matchers.{have_length, or_fail_with, should, succeed}
import dream_test/parallel
import dream_test/types
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Parallel executor", [
    it("can run a tree and return a report of the results", fn() {
      let tree =
        types.tree("Suite", Nil, [
          it("a", fn() { Ok(succeed()) }),
          it("b", fn() { Ok(succeed()) }),
        ])

      parallel.run_tree_parallel(parallel.default_config(), tree)
      |> types.report_tests
      |> should
      |> have_length(2)
      |> or_fail_with("expected two results")
    }),
  ])
}
