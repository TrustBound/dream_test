//// Black-box tests of owner processes: `sandbox.run_in_owner`,
//// `sandbox.check_owner` and `sandbox.stop_owner`.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox.{
  type OwnerResult, OwnerCaught, OwnerExited, OwnerLost, OwnerReturned,
  OwnerTimedOut,
}
import dream_test/unit.{describe, it}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Name}
import gleam/option.{None, Some}

pub fn tests() {
  describe("sandbox owner processes", [
    it("a new owner runs the function and returns its value", fn() {
      sandbox.run_in_owner(None, 1000, double, 21)
      |> summary
      |> should
      |> be_equal(Returned(42))
      |> or_fail_with("expected the value of the function")
    }),

    it("an owner catches a crash and stays alive for the next function", fn() {
      case sandbox.run_in_owner(None, 1000, crash_or_double, 0) {
        OwnerCaught(owner: owner, reason: reason) -> #(
          reason,
          summary(sandbox.run_in_owner(Some(owner), 1000, crash_or_double, 21)),
        )
        other -> #("not caught", summary(other))
      }
      |> should
      |> be_equal(#("error:boom", Returned(42)))
      |> or_fail_with("expected the crash and then the value")
    }),

    it("an owner that does not answer in time times out", fn() {
      sandbox.run_in_owner(None, 20, block_forever, 1000)
      |> summary
      |> should
      |> be_equal(TimedOut)
      |> or_fail_with("expected OwnerTimedOut")
    }),

    it("an owner that is killed during the function exits", fn() {
      sandbox.run_in_owner(None, 1000, kill_self, Nil)
      |> summary
      |> should
      |> be_equal(Exited("killed"))
      |> or_fail_with("expected OwnerExited(\"killed\")")
    }),

    it("a table that one function makes lives for the next function", fn() {
      let name = atom.create("dream_test_owner_table")
      case sandbox.run_in_owner(None, 1000, make_table, name) {
        OwnerReturned(owner: owner, value: _) ->
          summary(sandbox.run_in_owner(Some(owner), 1000, table_exists, name))
        other -> summary(other)
      }
      |> should
      |> be_equal(Returned(True))
      |> or_fail_with("expected the table to exist in the second function")
    }),

    it("a table of an owner is gone after stop_owner", fn() {
      let name = atom.create("dream_test_stopped_owner_table")
      case sandbox.run_in_owner(None, 1000, make_table, name) {
        OwnerReturned(owner: owner, value: _) -> {
          sandbox.stop_owner(owner)
          table_exists(name)
        }
        _other -> True
      }
      |> should
      |> be_equal(False)
      |> or_fail_with("expected the table to be gone")
    }),

    it("check_owner gives back an owner that is alive", fn() {
      case sandbox.run_in_owner(None, 1000, double, 21) {
        OwnerReturned(owner: owner, value: _) -> check_then_stop(owner)
        _other -> Error("did not start")
      }
      |> should
      |> be_equal(Ok(Nil))
      |> or_fail_with("expected the owner to be alive")
    }),

    it("an owner that stopped before the function gives OwnerLost", fn() {
      let crash = process.new_name("dream_test_crash")
      let ran = process.new_subject()
      case sandbox.run_in_owner(None, 1000, start_linked_crash, crash) {
        OwnerReturned(owner: owner, value: _) -> {
          crash_owner(crash)
          #(
            summary(sandbox.run_in_owner(
              Some(owner),
              1000,
              fn(_crash) { process.send(ran, "ran") },
              crash,
            )),
            process.receive(ran, 0),
          )
        }
        other -> #(summary(other), Error(Nil))
      }
      |> should
      |> be_equal(#(Lost("Boom"), Error(Nil)))
      |> or_fail_with("expected OwnerLost and a function that did not run")
    }),

    it("an owner that check_owner saw stop times out on the next call", fn() {
      let crash = process.new_name("dream_test_crash")
      case sandbox.run_in_owner(None, 1000, start_linked_crash, crash) {
        OwnerReturned(owner: owner, value: _) -> {
          crash_owner(crash)
          let _checked = sandbox.check_owner(owner)
          summary(sandbox.run_in_owner(
            Some(owner),
            20,
            start_linked_crash,
            crash,
          ))
        }
        other -> summary(other)
      }
      |> should
      |> be_equal(TimedOut)
      |> or_fail_with("expected OwnerTimedOut for an owner that was checked")
    }),

    it("check_owner gives the exit reason of an owner that stopped", fn() {
      let crash = process.new_name("dream_test_crash")
      case sandbox.run_in_owner(None, 1000, start_linked_crash, crash) {
        OwnerReturned(owner: owner, value: _) -> {
          crash_owner(crash)
          check_then_stop(owner)
        }
        _other -> Error("did not start")
      }
      |> should
      |> be_equal(Error("Boom"))
      |> or_fail_with("expected the exit reason of the owner")
    }),
  ])
}

/// What an `OwnerResult` says, with the owner stopped.
type Summary(output) {
  Returned(value: output)
  Caught(reason: String)
  TimedOut
  Exited(reason: String)
  Lost(reason: String)
}

fn summary(result: OwnerResult(input, output)) -> Summary(output) {
  case result {
    OwnerReturned(owner: owner, value: value) -> {
      sandbox.stop_owner(owner)
      Returned(value)
    }
    OwnerCaught(owner: owner, reason: reason) -> {
      sandbox.stop_owner(owner)
      Caught(reason)
    }
    OwnerTimedOut -> TimedOut
    OwnerExited(reason: reason) -> Exited(reason)
    OwnerLost(reason: reason) -> Lost(reason)
  }
}

fn check_then_stop(owner: sandbox.Owner(input, output)) -> Result(Nil, String) {
  case sandbox.check_owner(owner) {
    Ok(alive) -> {
      sandbox.stop_owner(alive)
      Ok(Nil)
    }
    Error(reason) -> Error(reason)
  }
}

fn double(number: Int) -> Int {
  number * 2
}

/// Crash for 0, else double.
fn crash_or_double(number: Int) -> Int {
  case number {
    0 -> erlang_error(atom.create("boom"))
    _ -> number * 2
  }
}

/// Never return, so the owner can only time out.
fn block_forever(number: Int) -> Int {
  process.sleep_forever()
  number * 2
}

fn kill_self(_input: Nil) -> Nil {
  process.kill(process.self())
}

/// Make a named table. Gives `True`, so it has the type of `table_exists`.
fn make_table(name: Atom) -> Bool {
  new_named_table(name)
  True
}

@external(erlang, "erlang", "error")
fn erlang_error(reason: Atom) -> a

@external(erlang, "dream_test_hook_resource_test_ffi", "new_named_table")
fn new_named_table(name: Atom) -> Nil

@external(erlang, "dream_test_hook_resource_test_ffi", "table_exists")
fn table_exists(name: Atom) -> Bool

/// The name of a process that `start_linked_crash` starts. It gets no
/// Gleam messages: `crash_owner` talks to it.
type Crash

/// Start a process that links to the caller and waits under `name`.
@external(erlang, "dream_test_hook_resource_test_ffi", "start_linked_crash")
fn start_linked_crash(name: Name(Crash)) -> Nil

/// Make the process under `name` exit with reason `boom`, then wait until
/// the owner that started it has exited.
@external(erlang, "dream_test_hook_resource_test_ffi", "crash_owner")
fn crash_owner(name: Name(Crash)) -> Nil
