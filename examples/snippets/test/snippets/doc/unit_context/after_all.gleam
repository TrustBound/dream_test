import dream_test/context
import dream_test/matchers.{succeed}
import dream_test/runner
import dream_test/types.{type RunReport}
import dream_test/unit_context.{after_all, describe, it}
import gleam/io

pub fn main() -> RunReport {
  runner.new([
    describe("Pool", context.value("pool-1"), [
      after_all(stop_pool),
      it("lends a connection", fn(_pool: String) { Ok(succeed()) }),
      it("takes it back", fn(_pool: String) { Ok(succeed()) }),
    ]),
  ])
  |> runner.run()
}

fn stop_pool(pool: String) -> Result(Nil, String) {
  io.println("stopping " <> pool)
  Ok(Nil)
}
