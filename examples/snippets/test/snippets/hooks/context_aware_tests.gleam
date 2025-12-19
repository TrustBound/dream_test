//// README: Context-aware tests (unit_context)
////
//// NOTE: This suite uses a custom context type, so it is intended to be run on
//// its own (see `main`). It is still compiled as part of `gleam test`.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters
import dream_test/runner
import dream_test/unit_context.{before_each, describe, it}
import gleam/io

pub type Ctx {
  Ctx(counter: Int)
}

fn increment(ctx: Ctx) {
  Ok(Ctx(counter: ctx.counter + 1))
}

pub fn suite() {
  describe("Context-aware suite", Ctx(counter: 0), [
    before_each(increment),
    it("receives the updated context", fn(ctx: Ctx) {
      ctx.counter
      |> should
      |> be_equal(1)
      |> or_fail_with("expected counter to be 1 after before_each")
    }),
    // Hook can be repeated; each applies to subsequent tests.
    before_each(increment),
    it("sees hook effects for subsequent tests", fn(ctx: Ctx) {
      ctx.counter
      |> should
      |> be_equal(2)
      |> or_fail_with("expected counter to be 2 after two before_each hooks")
    }),
  ])
}

pub fn compile_check() {
  let _ = suite()
  Nil
}

pub fn main() {
  runner.new([suite()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
