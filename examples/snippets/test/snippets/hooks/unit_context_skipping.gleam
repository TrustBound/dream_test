import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters
import dream_test/runner
import dream_test/unit_context.{describe, it, skip}
import gleam/io

pub type Context {
  Context(counter: Int)
}

pub fn suite() {
  describe("Skipping context-aware tests", Context(counter: 0), [
    skip("this test is skipped", fn(_context: Context) {
      // This would pass if it ran, but Dream Test will mark it skipped.
      Ok(succeed())
    }),
    it("normal tests still run", fn(context: Context) {
      context.counter
      |> should
      |> be_equal(0)
      |> or_fail_with("expected counter to start at 0")
    }),
  ])
}

pub fn main() {
  runner.new([suite()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
