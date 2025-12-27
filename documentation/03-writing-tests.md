## Writing unit tests (`describe`, `it`, `group`, `skip`, tags)

Most of the time, you want tests that read like a conversation with the code:

- “Here’s the behavior I’m testing” (`describe`)
- “Here’s one concrete thing that should be true” (`it`)

Dream Test’s unit DSL is built for that style, but there’s a deeper design goal behind the surface syntax:

- **Suites are just values** you can build, pass around, and run explicitly.
- **Your test module stays ordinary Gleam** (no hidden discovery side-effects).
- **Failures should read well** (because tests are communication, not just verification).

### `describe` + `it` (the core loop)

```gleam
import dream_test/matchers.{
  be_equal, be_error, be_ok, or_fail_with, should,
}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}
import snippets.{add, divide}

pub fn tests() {
  describe("Calculator", [
    it("adds two numbers", fn() {
      add(2, 3)
      |> should
      |> be_equal(5)
      |> or_fail_with("2 + 3 should equal 5")
    }),
    it("handles division", fn() {
      divide(10, 2)
      |> should
      |> be_ok()
      |> be_equal(5)
      |> or_fail_with("10 / 2 should equal 5")
    }),
    it("returns error for division by zero", fn() {
      divide(1, 0)
      |> should
      |> be_error()
      |> or_fail_with("Division by zero should error")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/unit/hero.gleam)</sub>

### How to think about `describe` and `it`

Treat the test structure (nested describes/groups/tests) as documentation:

- Use **`describe("Thing", [...])`** to name the unit of behavior you’re testing (a module, type, feature, capability).
- Use **short `it` names** that describe the outcome (“returns error for division by zero”), not the implementation (“calls divide with 0”).
- Keep `it` bodies small: arrange → act → assert.
- If setup gets noisy, prefer **named helpers** first. Reach for hooks when you truly need cross-cutting setup/teardown (see the lifecycle chapter).

### `skip` (keep the test, don’t run it)

Use `skip` when you want to keep the test structure and body around, but temporarily disable execution.

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it, skip}
import snippets.{add}

pub fn tests() {
  describe("Skipping tests", [
    it("runs normally", fn() {
      add(2, 3)
      |> should
      |> be_equal(5)
      |> or_fail_with("2 + 3 should equal 5")
    }),
    skip("not implemented yet", fn() {
      // This test is skipped - the body is preserved but not executed
      add(100, 200)
      |> should
      |> be_equal(300)
      |> or_fail_with("Should add large numbers")
    }),
    it("also runs normally", fn() {
      add(0, 0)
      |> should
      |> be_equal(0)
      |> or_fail_with("0 + 0 should equal 0")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/unit/skipping_tests.gleam)</sub>

Why `skip` exists (beyond “turn it off”):

- It keeps intent close to the code (“we know this should exist, but it’s not ready”).
- It avoids deleting tests (which often deletes context and makes regressions easier).
- It’s explicit: you still see it in the suite structure and output.

### `group` (structure inside a `describe`)

Use `group` when you want nested structure inside a suite: a second level of narrative under a `describe`.

The most common reason to use `group` is to scope hooks (setup/teardown) to a subset of tests. Even if you don’t use hooks, `group` can make long suites easier to skim.

Here’s the minimal shape:

```gleam
import dream_test/matchers.{succeed}
import dream_test/unit.{describe, group, it}

pub fn tests() {
  describe("Thing", [
    group("Case A", [
      it("does one thing", fn() { Ok(succeed()) }),
    ]),
    group("Case B", [
      it("does another thing", fn() { Ok(succeed()) }),
    ]),
  ])
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/unit/grouping.gleam)</sub>

You’ll also see `group` used in the hook inheritance example (outer hooks apply to inner groups):

```gleam
import dream_test/matchers.{succeed}
import dream_test/unit.{after_each, before_each, describe, group, it}
import gleam/io

pub fn tests() {
  describe("Outer", [
    before_each(fn() { io.println("outer setup") Ok(Nil) }),
    after_each(fn() { io.println("outer teardown") Ok(Nil) }),
    group("Inner", [
      before_each(fn() { io.println("inner setup") Ok(Nil) }),
      after_each(fn() { io.println("inner teardown") Ok(Nil) }),
      it("test", fn() { Ok(succeed()) }),
    ]),
  ])
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/hooks/hook_inheritance.gleam)</sub>

### Tags (when you need a “slice” of a suite)

Tags are lightweight labels you can attach to tests and groups. Use them to slice a run (“smoke”, “slow”, “integration”) or to filter/process results in your own tooling and CI.

What you can tag in unit tests:

- A **test** (an `it(...)` or `skip(...)` node)
- A **group** (a `group(...)` node)

Tags on a group apply to all tests inside that group (including nested groups).

Why tags exist:

- They let you annotate intent (“slow”, “integration”, “smoke”) without encoding that in names.
- They’re structured data that tools and reporters can use without parsing strings.

This repo also uses tags heavily in Gherkin specs (see the Gherkin guide), where tags live on scenarios/features.

### Filtering by tag

You can use tags to run only a subset of tests.

```gleam
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it, with_tags}
import gleam/list

fn is_smoke(info: runner.TestInfo) -> Bool {
  list.contains(info.tags, "smoke")
}

pub fn main() {
  let suite =
    describe("Tagged tests", [
      it("smoke: fast", fn() { Ok(AssertionOk) }) |> with_tags(["smoke"]),
      it("not smoke", fn() { Ok(AssertionOk) }),
    ])

  runner.new([suite])
  |> runner.filter_tests(is_smoke)
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

```gleam
import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, group, it, with_tags}

pub fn tests() {
  describe("Tagged tests", [
    // Tag a whole group (all tests inside inherit these tags)
    group("integration", [
      it("slow path", fn() { Ok(succeed()) }),
      it("another slow path", fn() { Ok(succeed()) }),
    ])
      |> with_tags(["integration", "slow"]),

    // Or tag a single test
    it("smoke", fn() { Ok(succeed()) })
      |> with_tags(["smoke"]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/unit/tagging.gleam)</sub>

### What's Next?

- Go back to [Quick Start](02-quick-start.md)
- Go back to [Documentation README](README.md)
- Continue to [Context-aware unit tests](04-context-aware-tests.md) if your setup produces a value you want to pass into every test (DB handle, client, scenario state).
