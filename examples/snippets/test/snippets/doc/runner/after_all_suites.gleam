import dream_test/matchers.{succeed}
import dream_test/runner
import dream_test/types.{type RunReport, type SuiteInfo}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/io
import gleam/list

pub fn main() -> RunReport {
  runner.new([
    describe("Cart", [
      it("starts empty", fn() { Ok(succeed()) }),
    ]),
    describe("Orders", [
      it("lists no orders", fn() { Ok(succeed()) }),
    ]),
  ])
  |> runner.after_all_suites(log_suites_run)
  |> runner.run()
}

fn log_suites_run(suites: List(SuiteInfo)) -> Result(Nil, String) {
  io.println("ran " <> int.to_string(list.length(suites)) <> " suites")
  Ok(Nil)
}
