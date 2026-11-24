import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}

pub fn main() -> RunReport {
  runner.new([
    describe("Cart", [
      it("starts empty", fn() { Ok(succeed()) }),
      it("counts two items", fn() {
        1
        |> should
        |> be_equal(2)
        |> or_fail_with("expected two items")
      }),
    ]),
  ])
  |> runner.results_reporters([bdd.new() |> bdd.failures_only()])
  |> runner.run()
}
