import dream_test/matchers.{be_between, be_equal, or_fail_with, should}
import dream_test/process
import dream_test/unit.{describe, it}
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

fn always_true() -> Bool {
  True
}

fn always_ok_42() -> Result(Int, Nil) {
  Ok(42)
}

pub fn tests() {
  describe("Process helpers", [
    it("start_counter + increment + get_count work", fn() {
      let counter = process.start_counter()
      process.increment(counter)
      process.increment(counter)

      process.get_count(counter)
      |> should
      |> be_equal(2)
      |> or_fail_with("expected counter to be 2")
    }),

    it("CounterMessage can be sent directly", fn() {
      let counter = process.start_counter()

      erlang_process.send(counter, process.Increment)
      erlang_process.send(counter, process.SetCount(10))

      process.get_count(counter)
      |> should
      |> be_equal(10)
      |> or_fail_with("expected counter to be 10 after SetCount")
    }),

    it("start_counter_with initializes the counter", fn() {
      let counter = process.start_counter_with(10)
      process.decrement(counter)

      process.get_count(counter)
      |> should
      |> be_equal(9)
      |> or_fail_with("expected counter to be 9 after decrement")
    }),

    it("set_count sets a counter to a specific value", fn() {
      let counter = process.start_counter()
      process.set_count(counter, 42)

      process.get_count(counter)
      |> should
      |> be_equal(42)
      |> or_fail_with("expected counter to be 42 after set_count")
    }),

    it("unique_port returns a value in the safe range", fn() {
      process.unique_port()
      |> should
      |> be_between(10_000, 60_000)
      |> or_fail_with("expected unique_port to be within 10k..60k")
    }),

    it("start_actor + call_actor work", fn() {
      let todos = process.start_actor([], handle_todo_message)

      erlang_process.send(todos, Add("Write tests"))
      erlang_process.send(todos, Add("Run tests"))

      process.call_actor(todos, GetAll, 1000)
      |> should
      |> be_equal(["Write tests", "Run tests"])
      |> or_fail_with("expected items to be preserved in insertion order")
    }),

    it("await_ready returns Ready(True) when the check returns True", fn() {
      process.await_ready(process.quick_poll_config(), always_true)
      |> should
      |> be_equal(process.Ready(True))
      |> or_fail_with("expected await_ready to return Ready(True)")
    }),

    it("await_some returns Ready(value) when the check returns Ok", fn() {
      process.await_some(process.default_poll_config(), always_ok_42)
      |> should
      |> be_equal(process.Ready(42))
      |> or_fail_with("expected await_some to return Ready(42)")
    }),

    it("default_poll_config has expected values", fn() {
      process.default_poll_config()
      |> should
      |> be_equal(process.PollConfig(timeout_ms: 5000, interval_ms: 50))
      |> or_fail_with("expected default_poll_config to be 5000ms/50ms")
    }),

    it("quick_poll_config has expected values", fn() {
      process.quick_poll_config()
      |> should
      |> be_equal(process.PollConfig(timeout_ms: 1000, interval_ms: 10))
      |> or_fail_with("expected quick_poll_config to be 1000ms/10ms")
    }),

    it("PortSelection can be constructed", fn() {
      process.Port(1234)
      |> should
      |> be_equal(process.Port(1234))
      |> or_fail_with("expected PortSelection to be constructible")
    }),
  ])
}
