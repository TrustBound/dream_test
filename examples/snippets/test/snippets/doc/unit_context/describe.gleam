import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit_context.{before_each, describe, it}

pub type Context {
  Context(counter: Int)
}

fn increment_counter(context: Context) -> Result(Context, String) {
  Ok(Context(counter: context.counter + 1))
}

pub fn suite() -> TestSuite {
  describe("Context-aware suite", context.value(Context(counter: 0)), [
    before_each(increment_counter),
    it("receives the updated context", fn(context: Context) {
      context.counter
      |> should
      |> be_equal(1)
      |> or_fail_with("expected counter to be 1 after before_each")
    }),
  ])
}

pub fn main() -> RunReport {
  runner.new([suite()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
