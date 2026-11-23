import dream_test/matchers.{succeed}
import dream_test/runner
import dream_test/types.{type RunReport}
import dream_test/unit_context.{after_each, describe, it}
import gleam/io

pub fn main() -> RunReport {
  runner.new([
    describe("Session", "session-1", [
      after_each(close_session),
      it("is open", fn(_session: String) { Ok(succeed()) }),
    ]),
  ])
  |> runner.run()
}

fn close_session(session: String) -> Result(Nil, String) {
  io.println("closing " <> session)
  Ok(Nil)
}
