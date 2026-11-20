import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit_context.{describe_with_setup, it}
import gleam/erlang/process.{type Subject}

pub type Request {
  Get(reply_to: Subject(Int))
  Stop
}

// The setup starts a process that holds a number. It lives while the tests
// run, because it runs in the process of the setup.

fn start_store() -> Result(Subject(Request), String) {
  let started = process.new_subject()
  process.spawn(fn() { serve(started) })
  case process.receive(started, 1000) {
    Ok(store) -> Ok(store)
    Error(Nil) -> Error("the store did not start")
  }
}

fn stop_store(store: Subject(Request)) -> Result(Nil, String) {
  process.send(store, Stop)
  Ok(Nil)
}

fn serve(started: Subject(Subject(Request))) -> Nil {
  let requests = process.new_subject()
  process.send(started, requests)
  answer(requests)
}

fn answer(requests: Subject(Request)) -> Nil {
  case process.receive_forever(requests) {
    Get(reply_to: reply_to) -> {
      process.send(reply_to, 42)
      answer(requests)
    }
    Stop -> Nil
  }
}

pub fn tests() {
  describe_with_setup(
    "Store",
    setup: start_store,
    teardown: stop_store,
    children: [
      it("gives the number", fn(store: Subject(Request)) {
        process.call(store, 1000, Get)
        |> should
        |> be_equal(42)
        |> or_fail_with("the store should give 42")
      }),
    ],
  )
}
