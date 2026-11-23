import dream_test/matchers.{succeed}
import dream_test/reporters/progress
import dream_test/runner
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}

pub fn main() -> RunReport {
  runner.new([
    describe("Cart", [
      it("starts empty", fn() { Ok(succeed()) }),
      it("adds an item", fn() { Ok(succeed()) }),
      it("removes an item", fn() { Ok(succeed()) }),
    ]),
  ])
  |> runner.progress_reporter(progress.new())
  |> runner.run()
}
