//// Black-box tests of setup processes: `sandbox.run_in_setup_process`,
//// `sandbox.check_setup_process` and `sandbox.stop_setup_process`.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox.{
  type SetupProcessResult, SetupProcessCaught, SetupProcessExited,
  SetupProcessLost, SetupProcessReturned, SetupProcessTimedOut,
}
import dream_test/unit.{describe, it}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Name, type Pid, type Subject}
import gleam/option.{None, Some}
import gleam/result

pub fn tests() {
  describe("sandbox setup processes", [
    it("a new setup process runs the function and returns its value", fn() {
      sandbox.run_in_setup_process(None, 1000, double, 21)
      |> summary
      |> should
      |> be_equal(Returned(42))
      |> or_fail_with("expected the value of the function")
    }),

    it(
      "a setup process catches a crash and stays alive for the next function",
      fn() {
        case sandbox.run_in_setup_process(None, 1000, crash_or_double, 0) {
          SetupProcessCaught(setup_process: setup_process, reason: reason) -> #(
            reason,
            summary(sandbox.run_in_setup_process(
              Some(setup_process),
              1000,
              crash_or_double,
              21,
            )),
          )
          other -> #("not caught", summary(other))
        }
        |> should
        |> be_equal(#("error:boom", Returned(42)))
        |> or_fail_with("expected the crash and then the value")
      },
    ),

    it("a setup process that does not answer in time times out", fn() {
      sandbox.run_in_setup_process(None, 20, block_forever, 1000)
      |> summary
      |> should
      |> be_equal(TimedOut)
      |> or_fail_with("expected SetupProcessTimedOut")
    }),

    it(
      "a setup process that timed out has exited when run_in_setup_process returns",
      fn() {
        let pids = process.new_subject()
        let result =
          sandbox.run_in_setup_process(None, 20, send_self_then_block, pids)
        #(
          summary(result),
          result.map(process.receive(pids, 0), process.is_alive),
        )
        |> should
        |> be_equal(#(TimedOut, Ok(False)))
        |> or_fail_with(
          "expected the setup process to be gone after SetupProcessTimedOut",
        )
      },
    ),

    it(
      "a setup process that is busy with another call times out before it starts",
      fn() {
        // Another process makes the setup process run a function that never returns.
        // A call from this process then cannot start, so it times out, and
        // the other call sees the setup process killed.
        let running = process.new_subject()
        let results = process.new_subject()
        case sandbox.run_in_setup_process(None, 1000, give_one, running) {
          SetupProcessReturned(setup_process: setup_process, value: _) -> {
            process.spawn(fn() {
              block_in_other_process(setup_process, running, results)
            })
            let _ = process.receive(running, 60_000)
            #(
              summary(sandbox.run_in_setup_process(
                Some(setup_process),
                20,
                give_one,
                running,
              )),
              process.receive(results, 60_000),
            )
          }
          other -> #(summary(other), Error(Nil))
        }
        |> should
        |> be_equal(#(TimedOut, Ok(Exited("killed"))))
        |> or_fail_with("expected a time-out, and the other call to see it")
      },
    ),

    it("a setup process that is killed during the function exits", fn() {
      sandbox.run_in_setup_process(None, 1000, kill_self, Nil)
      |> summary
      |> should
      |> be_equal(Exited("killed"))
      |> or_fail_with("expected SetupProcessExited(\"killed\")")
    }),

    it("a table that one function makes lives for the next function", fn() {
      let name = atom.create("dream_test_setup_process_table")
      case sandbox.run_in_setup_process(None, 1000, make_table, name) {
        SetupProcessReturned(setup_process: setup_process, value: _) ->
          summary(sandbox.run_in_setup_process(
            Some(setup_process),
            1000,
            table_exists,
            name,
          ))
        other -> summary(other)
      }
      |> should
      |> be_equal(Returned(True))
      |> or_fail_with("expected the table to exist in the second function")
    }),

    it("a table of a setup process is gone after stop_setup_process", fn() {
      let name = atom.create("dream_test_stopped_setup_process_table")
      case sandbox.run_in_setup_process(None, 1000, make_table, name) {
        SetupProcessReturned(setup_process: setup_process, value: _) -> {
          sandbox.stop_setup_process(setup_process)
          table_exists(name)
        }
        _other -> True
      }
      |> should
      |> be_equal(False)
      |> or_fail_with("expected the table to be gone")
    }),

    it("check_setup_process gives back a setup process that is alive", fn() {
      case sandbox.run_in_setup_process(None, 1000, double, 21) {
        SetupProcessReturned(setup_process: setup_process, value: _) ->
          check_then_stop(setup_process)
        _other -> Error("did not start")
      }
      |> should
      |> be_equal(Ok(Nil))
      |> or_fail_with("expected the setup process to be alive")
    }),

    it(
      "a setup process that stopped before the function gives SetupProcessLost",
      fn() {
        let crash = process.new_name("dream_test_crash")
        let ran = process.new_subject()
        case
          sandbox.run_in_setup_process(None, 1000, start_linked_crash, crash)
        {
          SetupProcessReturned(setup_process: setup_process, value: _) -> {
            crash_setup_process(crash)
            #(
              summary(sandbox.run_in_setup_process(
                Some(setup_process),
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
        |> or_fail_with(
          "expected SetupProcessLost and a function that did not run",
        )
      },
    ),

    it(
      "a setup process that check_setup_process saw stop gives SetupProcessLost on the next call",
      fn() {
        let crash = process.new_name("dream_test_crash")
        case
          sandbox.run_in_setup_process(None, 1000, start_linked_crash, crash)
        {
          SetupProcessReturned(setup_process: setup_process, value: _) -> {
            crash_setup_process(crash)
            let _checked = sandbox.check_setup_process(setup_process)
            summary(sandbox.run_in_setup_process(
              Some(setup_process),
              60_000,
              start_linked_crash,
              crash,
            ))
          }
          other -> summary(other)
        }
        |> should
        |> be_equal(Lost("the process had already stopped"))
        |> or_fail_with(
          "expected SetupProcessLost for a setup process that was checked",
        )
      },
    ),

    it(
      "stop_setup_process returns for a setup process that check_setup_process saw stop",
      fn() {
        sandbox.run_isolated(
          sandbox.SandboxConfig(timeout_ms: 60_000, show_crash_reports: False),
          check_then_stop_crashed_setup_process,
          process.new_name("dream_test_crash"),
        )
        |> should
        |> be_equal(sandbox.SandboxCompleted(Error("Boom")))
        |> or_fail_with(
          "expected stop_setup_process to return after check_setup_process",
        )
      },
    ),

    it(
      "check_setup_process in another process sees a setup process that stopped",
      fn() {
        let crash = process.new_name("dream_test_crash")
        case
          sandbox.run_in_setup_process(None, 1000, start_linked_crash, crash)
        {
          SetupProcessReturned(setup_process: setup_process, value: _) -> {
            crash_setup_process(crash)
            sandbox.run_isolated(
              sandbox.SandboxConfig(
                timeout_ms: 60_000,
                show_crash_reports: False,
              ),
              check_then_stop,
              setup_process,
            )
          }
          _other -> sandbox.SandboxCrashed("did not start")
        }
        |> should
        |> be_equal(
          sandbox.SandboxCompleted(Error("the process had already stopped")),
        )
        |> or_fail_with("expected the other process to see the stop")
      },
    ),

    it("stop_setup_process in another process stops the setup process", fn() {
      let name = atom.create("dream_test_other_process_stop_table")
      case sandbox.run_in_setup_process(None, 1000, make_table, name) {
        SetupProcessReturned(setup_process: setup_process, value: _) ->
          sandbox.run_isolated(
            sandbox.SandboxConfig(timeout_ms: 60_000, show_crash_reports: False),
            stop_then_check_table,
            #(setup_process, name),
          )
        _other -> sandbox.SandboxCrashed("did not start")
      }
      |> should
      |> be_equal(sandbox.SandboxCompleted(False))
      |> or_fail_with("expected the table of the setup process to be gone")
    }),

    it(
      "check_setup_process gives the exit reason of a setup process that stopped",
      fn() {
        let crash = process.new_name("dream_test_crash")
        case
          sandbox.run_in_setup_process(None, 1000, start_linked_crash, crash)
        {
          SetupProcessReturned(setup_process: setup_process, value: _) -> {
            crash_setup_process(crash)
            check_then_stop(setup_process)
          }
          _other -> Error("did not start")
        }
        |> should
        |> be_equal(Error("Boom"))
        |> or_fail_with("expected the exit reason of the setup process")
      },
    ),
  ])
}

/// What an `SetupProcessResult` says, with the setup process stopped.
type Summary(output) {
  Returned(value: output)
  Caught(reason: String)
  TimedOut
  Exited(reason: String)
  Lost(reason: String)
}

fn summary(result: SetupProcessResult(input, output)) -> Summary(output) {
  case result {
    SetupProcessReturned(setup_process: setup_process, value: value) -> {
      sandbox.stop_setup_process(setup_process)
      Returned(value)
    }
    SetupProcessCaught(setup_process: setup_process, reason: reason) -> {
      sandbox.stop_setup_process(setup_process)
      Caught(reason)
    }
    SetupProcessTimedOut -> TimedOut
    SetupProcessExited(reason: reason) -> Exited(reason)
    SetupProcessLost(reason: reason) -> Lost(reason)
  }
}

fn check_then_stop(
  setup_process: sandbox.SetupProcess(input, output),
) -> Result(Nil, String) {
  case sandbox.check_setup_process(setup_process) {
    Ok(alive) -> {
      sandbox.stop_setup_process(alive)
      Ok(Nil)
    }
    Error(reason) -> Error(reason)
  }
}

/// Start a setup process, make it stop, then check it and stop it. Gives the
/// result of the check.
fn check_then_stop_crashed_setup_process(
  crash: Name(Crash),
) -> Result(Nil, String) {
  case sandbox.run_in_setup_process(None, 1000, start_linked_crash, crash) {
    SetupProcessReturned(setup_process: setup_process, value: _) -> {
      crash_setup_process(crash)
      let checked = check_then_stop(setup_process)
      sandbox.stop_setup_process(setup_process)
      checked
    }
    _other -> Error("did not start")
  }
}

fn stop_then_check_table(
  input: #(sandbox.SetupProcess(Atom, Bool), Atom),
) -> Bool {
  let #(setup_process, name) = input
  sandbox.stop_setup_process(setup_process)
  table_exists(name)
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

/// Never return, so the setup process can only time out.
fn block_forever(number: Int) -> Int {
  process.sleep_forever()
  number * 2
}

/// Run a function in the setup process that says it is running and never returns,
/// then send what the call gave.
fn block_in_other_process(
  setup_process: sandbox.SetupProcess(Subject(Nil), Int),
  running: Subject(Nil),
  other: Subject(Summary(Int)),
) -> Nil {
  sandbox.run_in_setup_process(
    Some(setup_process),
    60_000,
    say_running_then_block,
    running,
  )
  |> summary
  |> process.send(other, _)
}

fn give_one(_running: Subject(Nil)) -> Int {
  1
}

fn say_running_then_block(running: Subject(Nil)) -> Int {
  process.send(running, Nil)
  process.sleep_forever()
  0
}

/// Send the pid of the setup process, then never return.
fn send_self_then_block(pids: Subject(Pid)) -> Nil {
  process.send(pids, process.self())
  process.sleep_forever()
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
/// Gleam messages: `crash_setup_process` talks to it.
type Crash

/// Start a process that links to the caller and waits under `name`.
@external(erlang, "dream_test_hook_resource_test_ffi", "start_linked_crash")
fn start_linked_crash(name: Name(Crash)) -> Nil

/// Make the process under `name` exit with reason `boom`, then wait until
/// the setup process that started it has exited.
@external(erlang, "dream_test_hook_resource_test_ffi", "crash_setup_process")
fn crash_setup_process(name: Name(Crash)) -> Nil
