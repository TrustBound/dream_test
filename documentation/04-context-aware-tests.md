## Context-aware unit tests (`dream_test/unit_context`)

`unit_context` is for the cases where you want to **pass a shared value into every test** (and have hooks transform it).

If you’ve ever built a DB handle, HTTP client, fixture, or “scenario state” and wished you could thread it through tests cleanly, this is the tool.

Use `dream_test/unit_context` when you want hooks and tests to operate on a shared, strongly-typed **context value** that you control.

### `unit` vs `unit_context`: same DSL names, different data flow

`dream_test/unit_context` intentionally mirrors the `dream_test/unit` DSL. You’ll see the **same function names** (`describe`, `it`, `group`, hooks like `before_each`, etc.) so you don’t have to learn a second vocabulary.

What changes is the **shape of the suite**:

- In `unit`, `describe("name", [...])` builds a suite where `it("name", fn() { ... })` has no context parameter.
- In `unit_context`, `describe("name", seed, [...])` builds a suite where `it("name", fn(context) { ... })` receives the current context value.

In practice, “switching” between them is mostly swapping the import:

#### The unit import <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/unit/dsl_import.gleam#L2-L2"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/unit.{describe, it}
```

#### The unit_context import <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/hooks/context_dsl_import.gleam#L2-L2"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/unit_context.{describe, it}
```

Tip: avoid importing _both_ sets of unqualified names in the same module—`describe`/`it` would collide. Pick one DSL per test module.

This is the right tool when:

- Your setup produces values you want to pass into the test body (DB handles, fixtures, clients).
- You want to model “state” explicitly and type-safely (instead of storing it in globals or rebuilding it in every test).
- You want hooks to _transform_ the context for each test.

If you don’t need an explicit context, prefer `dream_test/unit` — it’s simpler.

For setup/teardown that spans multiple suites, use runner-level hooks in [Runner & execution model](07-runner-and-execution.md).

### The idea: context flows through the suite

- You give `describe` an initial `seed` value.
- `before_all` / `before_each` can transform that context.
- Each `it` receives the current context.

### Why the seed exists

The `seed` might look redundant at first (“why not let `before_all` create the context?”), but it’s doing an important job: it makes the **context type known when the suite is built**, before any tests run.

That matters in Gleam because:

- The test structure is built as ordinary data, and its parts (`before_each`, `it`, etc.) are typed with a concrete `context` type.
- Hooks run at test time, but the compiler needs the context type at compile time so `it("...", fn(context) { ... })` is type-checked correctly.
- Practically: it keeps context-aware suites simple and predictable—no special “first hook defines the context” rule, and no loss of type-safety.

This is the “make dependencies explicit” version of hooks: instead of setup functions writing to global state (or relying on process dictionaries), the setup returns a value, and that value is passed into the test body.

### A context from a set-up (`describe_with_set_up`)

Sometimes the context is a resource that must start before the first test and stop after the last one, for example a server or a database pool. Use `describe_with_set_up` in place of `describe`:

- `set_up` runs one time, before the first test, and only when at least one test of the suite runs. Its value is the context of every hook and test.
- `tear_down` gets the same value after the last test.
- Both run in one process that lives while the tests run, so a process that the set-up starts stays alive.
- When `set_up` returns `Error`, crashes or times out, each test is `SetupFailed` and `tear_down` does not run. When `tear_down` fails, the run report gets a tear-down failure for the hook `tear_down`.

#### A suite whose context comes from a set-up <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/hooks/context_set_up.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit_context.{describe_with_set_up, it}
import gleam/erlang/process.{type Subject}

pub type Request {
  Get(reply_to: Subject(Int))
  Stop
}

// The set-up starts a process that holds a number. It lives while the tests
// run, because it runs in the process of the set-up.

fn start_store() -> Result(Subject(Request), String) {
  let started = process.new_subject()
  process.spawn(fn() { serve(started) })
  case process.receive(started, 1000) {
    Ok(store) -> Ok(store)
    Error(Nil) -> Error("the store did not start")
  }
}

fn stop_store(store: Subject(Request)) -> Result(Nil, String) {
  process.send(store, Stop)
  Ok(Nil)
}

fn serve(started: Subject(Subject(Request))) -> Nil {
  let requests = process.new_subject()
  process.send(started, requests)
  answer(requests)
}

fn answer(requests: Subject(Request)) -> Nil {
  case process.receive_forever(requests) {
    Get(reply_to: reply_to) -> {
      process.send(reply_to, 42)
      answer(requests)
    }
    Stop -> Nil
  }
}

pub fn tests() {
  describe_with_set_up(
    "Store",
    set_up: start_store,
    tear_down: stop_store,
    children: [
      it("gives the number", fn(store: Subject(Request)) {
        process.call(store, 1000, Get)
        |> should
        |> be_equal(42)
        |> or_fail_with("the store should give 42")
      }),
    ],
  )
}
```

### Context suites run with other suites

The context stays inside the suite, so every suite has the same type, `TestSuite`. One `runner.new` takes `unit` suites, `unit_context` suites with different context types, and Gherkin features. Module discovery also loads a context suite and runs it with its own context. See [Gherkin: a set-up for all scenarios](10-gherkin-bdd.md#a-set-up-for-all-scenarios-for-example-a-server) for a run with all three kinds.

### A minimal example: counter context

#### A counter context <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/hooks/context_aware_tests.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

### Grouping + hook scoping (`group`)

`unit_context.group` is the same idea as `unit.group`: it lets you nest structure, and it scopes hooks.

- Hooks declared in an **outer scope** apply inside nested groups.
- Hooks declared in an **inner group** apply only to tests in that group.

#### Hooks in context-aware groups <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/hooks/context_aware_grouping.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

### Important Gleam detail: when type inference needs help

In a context-aware test, you’ll often access record fields like `ctx.counter` or `context.captures`.
Gleam can only allow record-field access when it knows the record type, so sometimes you need a minimal type hint:

- `fn my_step(cart: Cart, context: StepContext) { ... context.captures ... }`

That’s not “extra ceremony” — it’s the smallest annotation needed for record field access.

### When to prefer plain `unit` instead

`unit_context` is great when setup produces something you want to reuse. But it’s not “better” by default.

Prefer `dream_test/unit` when:

- Your setup is tiny and reads well inline.
- You don’t need hooks to transform shared state.
- The context would just become another “thing you have to understand” without providing leverage.

### What's Next?

- Go back to [Writing unit tests](03-writing-tests.md)
- Go back to [Documentation README](README.md)
- Continue to [Assertions & matchers](05-assertions-and-matchers.md)
