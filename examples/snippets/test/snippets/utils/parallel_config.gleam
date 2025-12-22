import dream_test/matchers.{have_length, or_fail_with, should, succeed}
import dream_test/parallel.{ParallelConfig}
import dream_test/unit.{describe, it}

pub fn tests() {
  let config = ParallelConfig(max_concurrency: 2, default_timeout_ms: 1000)

  describe("ParallelConfig", [
    it("can be constructed to customize execution", fn() {
      let suite =
        describe("Suite", [
          it("a", fn() { Ok(succeed()) }),
        ])

      parallel.run_root_parallel(config, suite)
      |> should
      |> have_length(1)
      |> or_fail_with("expected one result")
    }),
  ])
}
