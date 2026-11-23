import dream_test/matchers.{succeed}
import dream_test/reporters/json
import dream_test/runner
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}

pub fn main() -> RunReport {
  runner.new([
    describe("Cart", [
      it("starts empty", fn() { Ok(succeed()) }),
    ]),
  ])
  |> runner.results_reporters([json.new() |> json.pretty()])
  |> runner.run()
}
