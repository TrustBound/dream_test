import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit_context.{before_each, describe, it}

pub type Context {
  Context(counter: Int)
}

fn increment_counter(context: Context) {
  Ok(Context(counter: context.counter + 1))
}

pub fn suite() {
  describe("Context-aware suite", Context(counter: 0), [
    before_each(increment_counter),
    it("receives the updated context", fn(context: Context) {
      context.counter
      |> should
      |> be_equal(1)
      |> or_fail_with("expected counter to be 1 after before_each")
    }),
    // Hook can be repeated; each applies to subsequent tests.
    before_each(increment_counter),
    it("sees hook effects for subsequent tests", fn(context: Context) {
      context.counter
      |> should
      |> be_equal(2)
      |> or_fail_with("expected counter to be 2 after two before_each hooks")
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
