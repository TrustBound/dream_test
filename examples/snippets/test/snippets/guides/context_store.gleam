import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit_context.{before_each, describe, it}
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}

/// A message to the user store: a small process that holds names by id.
pub type Message {
  Put(id: Int, name: String)
  Get(id: Int, reply_to: Subject(Result(String, Nil)))
  Stop
}

/// Starts the store, and gives the subject to send it messages.
pub fn start_store() -> Result(Subject(Message), String) {
  let started = process.new_subject()
  process.spawn(fn() { serve(started) })
  case process.receive(started, 1000) {
    Ok(store) -> Ok(store)
    Error(Nil) -> Error("the store did not start")
  }
}

pub fn stop_store(store: Subject(Message)) -> Result(Nil, String) {
  process.send(store, Stop)
  Ok(Nil)
}

fn serve(started: Subject(Subject(Message))) -> Nil {
  let messages = process.new_subject()
  process.send(started, messages)
  answer(messages, dict.new())
}

fn answer(messages: Subject(Message), names: Dict(Int, String)) -> Nil {
  case process.receive_forever(messages) {
    Put(id:, name:) -> answer(messages, dict.insert(names, id, name))
    Get(id:, reply_to:) -> {
      process.send(reply_to, dict.get(names, id))
      answer(messages, names)
    }
    Stop -> Nil
  }
}

pub fn tests() {
  describe("User store", context.setup(start_store, teardown: stop_store), [
    before_each(put_alice),
    it("finds a user by id", fn(store: Subject(Message)) {
      process.call(store, 1000, Get(1, _))
      |> should
      |> be_equal(Ok("Alice"))
      |> or_fail_with("the store should hold Alice as user 1")
    }),
    it("has no user 2", fn(store: Subject(Message)) {
      process.call(store, 1000, Get(2, _))
      |> should
      |> be_equal(Error(Nil))
      |> or_fail_with("the store should not hold user 2")
    }),
  ])
}

fn put_alice(store: Subject(Message)) -> Result(Subject(Message), String) {
  process.send(store, Put(1, "Alice"))
  Ok(store)
}
