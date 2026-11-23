import dream_test/matchers.{succeed}
import dream_test/runner
import dream_test/types.{type RunReport, type SuiteInfo}
import dream_test/unit.{describe, it}
import gleam/io

pub fn main() -> RunReport {
  runner.new([
    describe("Cart", [
      it("starts empty", fn() { Ok(succeed()) }),
    ]),
  ])
  |> runner.before_each_suite(log_suite_start)
  |> runner.run()
}

fn log_suite_start(info: SuiteInfo) -> Result(Nil, String) {
  io.println("starting suite " <> info.name)
  Ok(Nil)
}
