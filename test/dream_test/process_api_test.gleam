import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process as dt_process
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/erlang/process as beam_process
import gleam/int
import gleam/option.{None}
import gleam/otp/actor

pub type Msg {
  Add(String)
  GetAll(beam_process.Subject(List(String)))
}

fn handle_list_actor(
  state: List(String),
  msg: Msg,
) -> actor.Next(List(String), Msg) {
  case msg {
    Add(item) -> actor.continue([item, ..state])
    GetAll(reply) -> {
      beam_process.send(reply, state)
      actor.continue(state)
    }
  }
}

pub fn tests() {
  describe("dream_test/process", [
    it("counter helpers work", fn() {
      let counter = dt_process.start_counter()

      dt_process.get_count(counter)
      |> should
      |> be_equal(0)
      |> or_fail_with("start_counter should initialize to 0")
    }),

    it("counter increment/decrement/set_count work", fn() {
      let counter = dt_process.start_counter_with(10)
      dt_process.increment(counter)
      dt_process.increment(counter)
      dt_process.decrement(counter)
      dt_process.set_count(counter, 42)

      dt_process.get_count(counter)
      |> should
      |> be_equal(42)
      |> or_fail_with("counter should end at 42")
    }),

    it("unique_port returns a value in the safe range", fn() {
      let p = dt_process.unique_port()
      case p >= 10_000 && p < 60_000 {
        True -> Ok(types.AssertionOk)
        False ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "unique_port",
              message: "expected port in [10000, 60000), got "
                <> int.to_string(p),
              payload: None,
            )),
          )
      }
    }),

    it("start_actor + call_actor work", fn() {
      let todos = dt_process.start_actor([], handle_list_actor)
      beam_process.send(todos, Add("a"))
      beam_process.send(todos, Add("b"))

      let items = dt_process.call_actor(todos, GetAll, 1000)

      items
      |> should
      |> be_equal(["b", "a"])
      |> or_fail_with("actor should return items in LIFO order")
    }),

    it("default_poll_config and quick_poll_config have expected values", fn() {
      let dt_process.PollConfig(timeout_ms: t1, interval_ms: i1) =
        dt_process.default_poll_config()
      let dt_process.PollConfig(timeout_ms: t2, interval_ms: i2) =
        dt_process.quick_poll_config()

      case t1 == 5000 && i1 == 50 && t2 == 1000 && i2 == 10 {
        True -> Ok(types.AssertionOk)
        False ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "poll_config",
              message: "unexpected PollConfig values",
              payload: None,
            )),
          )
      }
    }),

    it("await_ready returns Ready(True) when the check succeeds", fn() {
      let config = dt_process.PollConfig(timeout_ms: 10, interval_ms: 1)
      case dt_process.await_ready(config, fn() { True }) {
        dt_process.Ready(True) -> Ok(types.AssertionOk)
        _ ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "await_ready",
              message: "expected Ready(True)",
              payload: None,
            )),
          )
      }
    }),

    it("await_ready returns TimedOut when the check never succeeds", fn() {
      let config = dt_process.PollConfig(timeout_ms: 2, interval_ms: 1)
      case dt_process.await_ready(config, fn() { False }) {
        dt_process.TimedOut -> Ok(types.AssertionOk)
        _ ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "await_ready",
              message: "expected TimedOut",
              payload: None,
            )),
          )
      }
    }),

    it("await_some returns Ready(value) when the check returns Ok", fn() {
      let config = dt_process.PollConfig(timeout_ms: 10, interval_ms: 1)
      case dt_process.await_some(config, fn() { Ok(123) }) {
        dt_process.Ready(123) -> Ok(types.AssertionOk)
        _ ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "await_some",
              message: "expected Ready(123)",
              payload: None,
            )),
          )
      }
    }),

    it("await_some returns TimedOut when the check never returns Ok", fn() {
      let config = dt_process.PollConfig(timeout_ms: 2, interval_ms: 1)
      case dt_process.await_some(config, fn() { Error(Nil) }) {
        dt_process.TimedOut -> Ok(types.AssertionOk)
        _ ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "await_some",
              message: "expected TimedOut",
              payload: None,
            )),
          )
      }
    }),
  ])
}
