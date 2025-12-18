## Context-aware unit tests (`dream_test/unit_context`)

`unit_context` is for the cases where you want to **pass a shared value into every test** (and have hooks transform it).

If you’ve ever built a DB handle, HTTP client, fixture, or “scenario state” and wished you could thread it through tests cleanly, this is the tool.

Use `dream_test/unit_context` when you want hooks and tests to operate on a shared, strongly-typed **context value** that you control.

This is the right tool when:

- Your setup produces values you want to pass into the test body (DB handles, fixtures, clients).
- You want to model “state” explicitly and type-safely (instead of storing it in globals or rebuilding it in every test).
- You want hooks to _transform_ the context for each test.

If you don’t need an explicit context, prefer `dream_test/unit` — it’s simpler.

### The idea: context flows through the suite

- You give `describe` an initial `seed` value.
- `before_all` / `before_each` can transform that context.
- Each `it` receives the current context.

### A minimal example: counter context

```gleam
import dream_test/assertions/should.{equal, or_fail_with, should}
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

fn counter_is_one(ctx: Ctx) {
  ctx.counter
  |> should()
  |> equal(1)
  |> or_fail_with("expected counter to be 1 after before_each")
}

fn counter_is_two(ctx: Ctx) {
  ctx.counter
  |> should()
  |> equal(2)
  |> or_fail_with("expected counter to be 2 after two before_each hooks")
}

pub fn suite() {
  describe("Context-aware suite", Ctx(counter: 0), [
    before_each(increment),
    it("receives the updated context", counter_is_one),
    // Hook can be repeated; each applies to subsequent tests.
    before_each(increment),
    it("sees hook effects for subsequent tests", counter_is_two),
  ])
}

pub fn main() {
  runner.new([suite()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/hooks/context_aware_tests.gleam)</sub>

### Important Gleam detail: when type inference needs help

In a context-aware test, you’ll often access record fields like `ctx.counter` or `context.world`.
Gleam can only allow record-field access when it knows the record type, so sometimes you need a minimal type hint:

- `fn my_step(context: StepContext) { ... context.world ... }`

That’s not “extra ceremony” — it’s the smallest annotation needed for record field access.
