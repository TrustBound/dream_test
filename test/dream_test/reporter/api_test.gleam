import dream_test/reporters
import dream_test/reporters/types as reporter_types
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/erlang/process as beam_process
import gleam/option.{None}
import gleam/otp/actor

pub type OutMsg {
  Write(String)
  GetAll(beam_process.Subject(List(String)))
}

fn handle_out(
  state: List(String),
  msg: OutMsg,
) -> actor.Next(List(String), OutMsg) {
  case msg {
    Write(line) -> actor.continue([line, ..state])
    GetAll(reply) -> {
      beam_process.send(reply, state)
      actor.continue(state)
    }
  }
}

fn start_out() -> beam_process.Subject(OutMsg) {
  let assert Ok(started) =
    actor.new([])
    |> actor.on_message(handle_out)
    |> actor.start
  started.data
}

fn read_out(out: beam_process.Subject(OutMsg)) -> List(String) {
  actor.call(out, waiting: 1000, sending: GetAll)
}

pub fn tests() {
  describe("dream_test/reporters", [
    it(
      "bdd/json/progress constructors and handle_event do not crash and write on RunFinished",
      fn() {
        let out = start_out()
        let write = fn(s: String) { beam_process.send(out, Write(s)) }

        let result =
          types.TestResult(
            name: "t",
            full_name: ["suite", "t"],
            status: types.Passed,
            duration_ms: 1,
            tags: [],
            failures: [],
            kind: types.Unit,
          )

        let r0 = reporters.bdd(write, False)
        let r1 = reporters.handle_event(r0, reporter_types.RunStarted(total: 1))
        let r2 =
          reporters.handle_event(
            r1,
            reporter_types.TestFinished(completed: 1, total: 1, result: result),
          )
        let _r3 =
          reporters.handle_event(
            r2,
            reporter_types.RunFinished(completed: 1, total: 1),
          )

        // Also ensure constructors exist and don't crash.
        let _ = reporters.json(write, False)
        let _ = reporters.progress(write)

        case read_out(out) {
          [] ->
            Ok(
              types.AssertionFailed(types.AssertionFailure(
                operator: "reporter",
                message: "expected reporter to write output on RunFinished",
                payload: None,
              )),
            )
          _ -> Ok(types.AssertionOk)
        }
      },
    ),
  ])
}
