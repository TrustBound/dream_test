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
  |> runner.after_each_suite(log_suite_end)
  |> runner.run()
}

fn log_suite_end(info: SuiteInfo) -> Result(Nil, String) {
  io.println("finished suite " <> info.name)
  Ok(Nil)
}
