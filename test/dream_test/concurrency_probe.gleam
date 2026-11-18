//// A process that counts the tests that run at the same time, for tests
//// of `max_concurrency`. It uses messages only, so the result does not
//// depend on the speed of the machine.
////
//// Each test body calls `run`. The probe counts the bodies that run now
//// and keeps the highest count. With a barrier of N, no body goes on until
//// N bodies run at the same time. A run that cannot run N bodies at the
//// same time thus blocks until its test timeout.
////
//// The probe stops when the process that started it exits, so it never
//// outlives its test.

import dream_test/types.{type AssertionResult, AssertionOk}
import gleam/erlang/process.{type Name, type Subject}
import gleam/list

/// A probe from `start`.
pub opaque type Probe {
  Probe(name: Name(Message))
}

type Message {
  Enter(reply: Subject(Nil))
  Leave(reply: Subject(Nil))
  Peak(reply: Subject(Int))
  OwnerDown
}

type State {
  State(
    barrier: Int,
    running: Int,
    peak: Int,
    waiting: List(Subject(Nil)),
    open: Bool,
  )
}

/// Start a probe. No body goes on until `barrier` bodies run at the same
/// time. A barrier of 1 lets each body go on at once.
pub fn start(barrier: Int) -> Probe {
  let owner = process.self()
  let name = process.new_name("dream_test_probe")
  let pid = process.spawn_unlinked(fn() { init(name, owner, barrier) })
  let assert Ok(Nil) = process.register(pid, name)
  Probe(name)
}

/// A test body: tell the probe that it runs, wait for the barrier, then
/// tell the probe that it ends.
pub fn run(probe: Probe) -> Result(AssertionResult, String) {
  let subject = process.named_subject(probe.name)
  process.call_forever(subject, Enter)
  process.call_forever(subject, Leave)
  Ok(AssertionOk)
}

/// The highest number of bodies that ran at the same time.
pub fn peak(probe: Probe) -> Int {
  process.call_forever(process.named_subject(probe.name), Peak)
}

fn init(name: Name(Message), owner: process.Pid, barrier: Int) -> Nil {
  let monitor = process.monitor(owner)
  let selector =
    process.new_selector()
    |> process.select(process.named_subject(name))
    |> process.select_specific_monitor(monitor, fn(_down) { OwnerDown })
  loop(
    selector,
    State(barrier: barrier, running: 0, peak: 0, waiting: [], open: False),
  )
}

fn loop(selector: process.Selector(Message), state: State) -> Nil {
  case process.selector_receive_forever(selector) {
    Enter(reply) -> loop(selector, enter(state, reply))
    Leave(reply) -> {
      process.send(reply, Nil)
      loop(selector, State(..state, running: state.running - 1))
    }
    Peak(reply) -> {
      process.send(reply, state.peak)
      loop(selector, state)
    }
    OwnerDown -> Nil
  }
}

fn enter(state: State, reply: Subject(Nil)) -> State {
  let running = state.running + 1
  let peak = case running > state.peak {
    True -> running
    False -> state.peak
  }
  let waiting = [reply, ..state.waiting]
  case state.open || list.length(waiting) >= state.barrier {
    True -> {
      list.each(waiting, fn(subject) { process.send(subject, Nil) })
      State(..state, running: running, peak: peak, waiting: [], open: True)
    }
    False -> State(..state, running: running, peak: peak, waiting: waiting)
  }
}
