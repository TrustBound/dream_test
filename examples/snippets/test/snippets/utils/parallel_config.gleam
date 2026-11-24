import dream_test/matchers.{have_length, or_fail_with, should, succeed}
import dream_test/parallel.{ParallelConfig}
import dream_test/types
import dream_test/unit.{describe, it}

pub fn tests() {
  let config = ParallelConfig(max_concurrency: 2, default_timeout_ms: 1000)

  describe("ParallelConfig", [
    it("can be constructed to customize execution", fn() {
      let tree =
        types.tree("Suite", Nil, [
          it("a", fn() { Ok(succeed()) }),
        ])

      parallel.run_tree_parallel(config, tree)
      |> types.report_tests
      |> should
      |> have_length(1)
      |> or_fail_with("expected one result")
    }),
  ])
}
