import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process
import dream_test/types.{type AssertionResult}
import gleam/erlang/process as erlang_process
import gleam/list
import gleam/otp/actor

pub type TodoMessage {
  Add(String)
  GetAll(erlang_process.Subject(List(String)))
}

fn handle_todo_message(
  items: List(String),
  message: TodoMessage,
) -> actor.Next(List(String), TodoMessage) {
  case message {
    Add(item) -> actor.continue(list.append(items, [item]))
    GetAll(reply_to) -> {
      erlang_process.send(reply_to, items)
      actor.continue(items)
    }
  }
}

pub fn todos_keep_insertion_order() -> Result(AssertionResult, String) {
  let todos = process.start_actor([], handle_todo_message)

  erlang_process.send(todos, Add("Write tests"))
  erlang_process.send(todos, Add("Run tests"))

  process.call_actor(todos, GetAll, 1000)
  |> should
  |> be_equal(["Write tests", "Run tests"])
  |> or_fail_with("expected items to be preserved in insertion order")
}
