import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process as dt_process
import dream_test/runner
import dream_test/types
import dream_test/unit.{describe, it}
import dream_test/unit_context
import gleam/erlang/process as beam_process
import gleam/int
import gleam/option.{None}
import gleam/otp/actor
import gleam/result

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
    it("a linked counter stops when its test ends", fn() {
      // Each test starts a counter that links to its test process and
      // sends the counter process out. The tests pass, fail and crash.
      // When the run returns, each counter must stop.
      let counters = beam_process.new_subject()
      runner.new([
        describe("linked", [
          it("passes", fn() {
            start_counter_then(counters, Ok(types.AssertionOk))
          }),
          it("fails", fn() { start_counter_then(counters, Error("fails")) }),
          it("crashes", fn() { start_counter_then_crash(counters) }),
        ]),
      ])
      |> runner.silent()
      |> runner.run()
      |> fn(_report) {
        [receive_down(counters), receive_down(counters), receive_down(counters)]
      }
      |> should
      |> be_equal([Ok(Nil), Ok(Nil), Ok(Nil)])
      |> or_fail_with("each linked counter should stop with its test")
    }),

    it("a linked counter that a context setup starts stops after the run", fn() {
      // The setup starts a counter that links to the setup process and
      // does not trap exits. The teardown leaves it alone. When the run
      // returns, the counter must stop with the setup process.
      let counters = beam_process.new_subject()
      runner.new([
        unit_context.describe_with_setup(
          "setup",
          setup: fn() { start_counter_in_setup(counters) },
          teardown: leave_counter,
          children: [unit_context.it("passes", counter_context_passes)],
        ),
      ])
      |> runner.silent()
      |> runner.run()
      |> fn(_report) { receive_down(counters) }
      |> should
      |> be_equal(Ok(Nil))
      |> or_fail_with("the counter of the setup should stop after the run")
    }),

    it("a linked counter that before_all starts stops after the run", fn() {
      let counters = beam_process.new_subject()
      runner.new([
        describe("before_all", [
          unit.before_all(fn() { start_counter_in_before_all(counters) }),
          it("passes", passes),
        ]),
      ])
      |> runner.silent()
      |> runner.run()
      |> fn(_report) { receive_down(counters) }
      |> should
      |> be_equal(Ok(Nil))
      |> or_fail_with("the counter of before_all should stop after the run")
    }),

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

    it("await_ready times out with an interval of 0", fn() {
      dt_process.await_ready(
        dt_process.PollConfig(timeout_ms: 20, interval_ms: 0),
        fn() { False },
      )
      |> should
      |> be_equal(dt_process.TimedOut)
      |> or_fail_with("expected TimedOut with interval_ms: 0")
    }),

    it("await_some times out with an interval of 0", fn() {
      dt_process.await_some(
        dt_process.PollConfig(timeout_ms: 20, interval_ms: 0),
        fn() { Error(Nil) },
      )
      |> should
      |> be_equal(dt_process.TimedOut)
      |> or_fail_with("expected TimedOut with interval_ms: 0")
    }),

    it("await_ready does not call the check with a timeout of 0", fn() {
      dt_process.await_ready(
        dt_process.PollConfig(timeout_ms: 0, interval_ms: 10),
        fn() { True },
      )
      |> should
      |> be_equal(dt_process.TimedOut)
      |> or_fail_with("expected TimedOut before any check")
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

fn start_counter_then(
  counters: beam_process.Subject(beam_process.Pid),
  result: Result(types.AssertionResult, String),
) -> Result(types.AssertionResult, String) {
  let counter = dt_process.start_counter()
  let assert Ok(pid) = beam_process.subject_owner(counter)
  beam_process.send(counters, pid)
  result
}

fn start_counter_then_crash(
  counters: beam_process.Subject(beam_process.Pid),
) -> Result(types.AssertionResult, String) {
  let _ = start_counter_then(counters, Ok(types.AssertionOk))
  panic as "crashes"
}

/// Take the next counter process, and wait until it has stopped. Gives an
/// error when it does not stop.
fn receive_down(
  counters: beam_process.Subject(beam_process.Pid),
) -> Result(Nil, String) {
  case beam_process.receive(counters, 60_000) {
    Ok(pid) -> wait_for_down(pid)
    Error(Nil) -> Error("no counter")
  }
}

fn wait_for_down(pid: beam_process.Pid) -> Result(Nil, String) {
  let monitor = beam_process.monitor(pid)
  beam_process.new_selector()
  |> beam_process.select_specific_monitor(monitor, ignore_down)
  |> beam_process.selector_receive(60_000)
  |> result.replace_error("the counter is still alive")
}

fn ignore_down(_down: beam_process.Down) -> Nil {
  Nil
}

fn start_counter_in_setup(
  counters: beam_process.Subject(beam_process.Pid),
) -> Result(beam_process.Pid, String) {
  let counter = dt_process.start_counter()
  let assert Ok(pid) = beam_process.subject_owner(counter)
  beam_process.send(counters, pid)
  Ok(pid)
}

fn leave_counter(_counter: beam_process.Pid) -> Result(Nil, String) {
  Ok(Nil)
}

fn counter_context_passes(
  _counter: beam_process.Pid,
) -> Result(types.AssertionResult, String) {
  Ok(types.AssertionOk)
}

fn start_counter_in_before_all(
  counters: beam_process.Subject(beam_process.Pid),
) -> Result(Nil, String) {
  start_counter_in_setup(counters)
  |> result.replace(Nil)
}

fn passes() -> Result(types.AssertionResult, String) {
  Ok(types.AssertionOk)
}
