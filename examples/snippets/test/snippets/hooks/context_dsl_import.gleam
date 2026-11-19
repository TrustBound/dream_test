import dream_test/matchers.{be_false, or_fail_with, should, succeed}
import dream_test/runner
import dream_test/types
import dream_test/unit
import dream_test/unit_context.{describe, it}

pub fn suite() {
  describe("unit_context DSL", 0, [
    it("receives the context", fn(_context: Int) { Ok(succeed()) }),
  ])
}

/// Discovery runs only suites without a context, so this unit test runs
/// the context suite with its own runner.
pub fn tests() {
  unit.describe("unit_context DSL", [
    unit.it("runs the context suite", fn() {
      runner.new([suite()])
      |> runner.silent()
      |> runner.run()
      |> types.failed
      |> should
      |> be_false()
      |> or_fail_with("the context suite should pass")
    }),
  ])
}
