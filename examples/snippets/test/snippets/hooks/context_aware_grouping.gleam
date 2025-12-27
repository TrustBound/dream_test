import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit_context.{before_each, describe, group, it}

pub type Context {
  Context(counter: Int)
}

fn increment_counter(context: Context) {
  Ok(Context(counter: context.counter + 1))
}

pub fn suite() {
  describe("Context-aware grouping", Context(counter: 0), [
    // This outer hook applies everywhere under this describe, including groups.
    before_each(increment_counter),

    group("inner group", [
      // This hook only applies to tests inside this group.
      before_each(increment_counter),

      it("sees both outer + inner hooks", fn(context: Context) {
        context.counter
        |> should
        |> be_equal(2)
        |> or_fail_with("expected counter to be 2 (outer + inner before_each)")
      }),
    ]),

    it("sees only outer hook", fn(context: Context) {
      context.counter
      |> should
      |> be_equal(1)
      |> or_fail_with("expected counter to be 1 (outer before_each only)")
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
