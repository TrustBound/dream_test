//// The "Don't" example of the allowed process start closure of rule 2 of
//// STANDARDS.md: the closure holds the logic. It compiles and works, but
//// the `case` is in an anonymous function.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/erlang/process.{type Pid, type Subject, send, spawn_unlinked}
import snippets/standards/worker_messages.{
  type WorkerMessage, TestCompleted, caught_message, run_catching,
}

pub fn start_worker(
  result_subject: Subject(WorkerMessage(a)),
  run: fn(input) -> a,
  input: input,
  show_crash_reports: Bool,
) -> Pid {
  spawn_unlinked(fn() {
    case show_crash_reports {
      True -> send(result_subject, TestCompleted(run(input)))
      False -> send(result_subject, caught_message(run_catching(run, input)))
    }
  })
}

fn double(number: Int) -> Int {
  number * 2
}

pub fn tests() {
  describe("STANDARDS.md rule 2, Don't: logic in a process start closure", [
    it("sends the result of the worker", fn() {
      // Arrange
      let result_subject = process.new_subject()
      start_worker(result_subject, double, 21, False)

      // Act
      let message = process.receive(result_subject, 1000)

      // Assert
      message
      |> should
      |> be_equal(Ok(TestCompleted(42)))
      |> or_fail_with("the worker should send 42")
    }),
  ])
}
