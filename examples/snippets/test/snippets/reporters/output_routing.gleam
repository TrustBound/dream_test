import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/erlang/process as beam_process
import gleam/list
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

fn read_out(out: beam_process.Subject(OutMsg)) -> String {
  actor.call(out, waiting: 1000, sending: GetAll)
  |> list.reverse
  |> string.concat
}

pub fn main() {
  let out = start_out()
  let write = fn(s: String) { beam_process.send(out, Write(s)) }
  let output = runner.Output(out: write, error: write)

  let _results =
    runner.new([example_suite()])
    |> runner.progress_reporter(progress.new())
    |> runner.results_reporters([bdd.new() |> bdd.summary_only()])
    |> runner.output(output)
    |> runner.run()

  let captured = read_out(out)
  // Now you can snapshot/parse/write `captured` however you want.
  let _ = captured
  Nil
}

fn example_suite() {
  describe("Example Suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn tests() {
  describe("Custom output routing", [
    it("captures the runner output instead of printing it", fn() {
      main()
      Ok(succeed())
    }),
  ])
}
