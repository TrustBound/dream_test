import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit_context.{
  after_all, after_each, before_all, before_each, describe, it,
}
import gleam/int
import gleam/io

pub type Context {
  Context(counter: Int)
}

fn setup_suite(_context: Context) {
  Ok(Context(counter: 0))
}

fn setup_test(context: Context) {
  Ok(Context(counter: context.counter + 1))
}

// Teardown hooks commonly do side effects (closing files, deleting temp dirs,
// logging, etc). The hook returns `Ok(Nil)` because teardown doesn’t produce
// a new context value.
fn teardown_test(context: Context) {
  Ok(io.println("after_each: counter=" <> int.to_string(context.counter)))
}

fn teardown_suite(_context: Context) {
  Ok(io.println("after_all: suite finished"))
}

pub fn suite() {
  describe("Context lifecycle hooks", Context(counter: 999), [
    before_all(setup_suite),
    before_each(setup_test),
    after_each(teardown_test),
    after_all(teardown_suite),
    it("runs with the transformed context", fn(context: Context) {
      context.counter
      |> should
      |> be_equal(1)
      |> or_fail_with("counter mismatch")
    }),
  ])
}

pub fn main() {
  runner.new([suite()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
