import dream_test/context
import dream_test/matchers.{be_equal, have_length, or_fail_with, should}
import dream_test/runner
import dream_test/types
import dream_test/unit
import dream_test/unit_context.{before_each, describe, it}
import gleam/erlang/process.{type Subject}
import gleam/list

pub type Context {
  Context(inbox: Subject(String))
}

pub fn suite() {
  describe("Inbox", context.value(Context(inbox: process.new_subject())), [
    before_each(fn(_context) {
      let inbox = process.new_subject()
      process.send(inbox, "welcome")
      Ok(Context(inbox: inbox))
    }),
    it("gets the message that its hook sent", fn(context: Context) {
      process.receive(context.inbox, 100)
      |> should
      |> be_equal(Ok("welcome"))
      |> or_fail_with("expected the message from the before_each hook")
    }),
  ])
}

pub fn tests() {
  unit.describe("Hooks and processes", [
    unit.it("a test and its before_each hook share a process", fn() {
      runner.new([suite()])
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> list.filter(fn(result) { result.status == types.Passed })
      |> should
      |> have_length(1)
      |> or_fail_with("expected the inbox test to pass")
    }),
  ])
}
