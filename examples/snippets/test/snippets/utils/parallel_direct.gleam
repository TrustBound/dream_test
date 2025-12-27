import dream_test/matchers.{have_length, or_fail_with, should, succeed}
import dream_test/parallel
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Parallel executor", [
    it("can run a suite and return a list of results", fn() {
      let suite =
        describe("Suite", [
          it("a", fn() { Ok(succeed()) }),
          it("b", fn() { Ok(succeed()) }),
        ])

      parallel.run_root_parallel(parallel.default_config(), suite)
      |> should
      |> have_length(2)
      |> or_fail_with("expected two results")
    }),
  ])
}
