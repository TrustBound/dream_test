import dream_test/matchers.{succeed}
import dream_test/runner
import dream_test/types.{type RunReport, type TestInfo}
import dream_test/unit.{describe, it}
import gleam/io

pub fn main() -> RunReport {
  runner.new([
    describe("Cart", [
      it("starts empty", fn() { Ok(succeed()) }),
    ]),
  ])
  |> runner.after_each_test(log_finished_test)
  |> runner.run()
}

fn log_finished_test(info: TestInfo) -> Result(Nil, String) {
  io.println("finished " <> info.name)
  Ok(Nil)
}
