import dream_test/reporters/bdd
import dream_test/reporters/json
import dream_test/reporters/progress
import dream_test/runner
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/erlang/process as beam_process
import gleam/list
import gleam/option.{None}
import gleam/otp/actor
import gleam/string

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
  describe("dream_test reporting", [
    it("progress + results reporters write output and do not crash", fn() {
      let out = start_out()
      let write = fn(s: String) { beam_process.send(out, Write(s)) }

      let output = runner.Output(out: write, error: write)

      let _results =
        runner.new([example_suite()])
        |> runner.progress_reporter(progress.new())
        |> runner.results_reporters([
          bdd.new() |> bdd.summary_only(),
          json.new(),
        ])
        |> runner.output(output)
        |> runner.run()

      let combined =
        read_out(out)
        |> list.reverse
        |> string.concat

      case string.contains(combined, "Summary:") {
        True -> Ok(types.AssertionOk)
        False ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "reporting",
              message: "expected output to include a Summary line",
              payload: None,
            )),
          )
      }
    }),
  ])
}

fn example_suite() {
  describe("Example Suite", [
    it("passes", fn() { Ok(types.AssertionOk) }),
  ])
}
