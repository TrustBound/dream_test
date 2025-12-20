//// README: Context-aware grouping (`unit_context.group`)
////
//// Demonstrates:
//// - Using `group` in `unit_context`
//// - Hook scoping: outer hooks apply to inner groups, and inner hooks only
////   apply within that group.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters
import dream_test/runner
import dream_test/unit_context.{before_each, describe, group, it}
import gleam/io

pub type Ctx {
  Ctx(counter: Int)
}

fn inc(ctx: Ctx) {
  Ok(Ctx(counter: ctx.counter + 1))
}

pub fn suite() {
  describe("Context-aware grouping", Ctx(counter: 0), [
    // This outer hook applies everywhere under this describe, including groups.
    before_each(inc),

    group("inner group", [
      // This hook only applies to tests inside this group.
      before_each(inc),

      it("sees both outer + inner hooks", fn(ctx: Ctx) {
        ctx.counter
        |> should
        |> be_equal(2)
        |> or_fail_with("expected counter to be 2 (outer + inner before_each)")
      }),
    ]),

    it("sees only outer hook", fn(ctx: Ctx) {
      ctx.counter
      |> should
      |> be_equal(1)
      |> or_fail_with("expected counter to be 1 (outer before_each only)")
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
