## Writing unit tests (`describe`, `it`, `group`, `skip`, tags)

Most of the time, you want tests that read like a conversation with the code:

- “Here’s the behavior I’m testing” (`describe`)
- “Here’s one concrete thing that should be true” (`it`)

Dream Test’s unit DSL is built for that style, but there’s a deeper design goal behind the surface syntax:

- **Suites are just values** you can build, pass around, and run explicitly.
- **Your test module stays ordinary Gleam** (no hidden discovery side-effects).
- **Failures should read well** (because tests are communication, not just verification).

If you need setup/teardown that spans multiple suites, use runner-level hooks in [Runner & execution model](07-runner-and-execution.md).

### `describe` + `it` (the core loop)

#### Describe and it <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/unit/hero.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, be_error, be_ok, or_fail_with, should}
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

### How to think about `describe` and `it`

Treat the test structure (nested describes/groups/tests) as documentation:

- Use **`describe("Thing", [...])`** to name the unit of behavior you’re testing (a module, type, feature, capability).
- Use **short `it` names** that describe the outcome (“returns error for division by zero”), not the implementation (“calls divide with 0”).
- Keep `it` bodies small: arrange → act → assert.
- If setup gets noisy, prefer **named helpers** first. Reach for hooks when you truly need cross-cutting setup/teardown (see the lifecycle chapter).

### `skip` (keep the test, don’t run it)

Use `skip` when you want to keep the test structure and body around, but temporarily disable execution.

#### Skip a test <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/unit/skipping_tests.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

Why `skip` exists (beyond “turn it off”):

- It keeps intent close to the code (“we know this should exist, but it’s not ready”).
- It avoids deleting tests (which often deletes context and makes regressions easier).
- It’s explicit: you still see it in the suite structure and output.

### `group` (structure inside a `describe`)

Use `group` when you want nested structure inside a suite: a second level of narrative under a `describe`.

The most common reason to use `group` is to scope hooks (setup/teardown) to a subset of tests. Even if you don’t use hooks, `group` can make long suites easier to skim.

Here’s the shape:

#### Groups in a suite <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/unit/grouping.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, group, it}

pub fn tests() {
  describe("Calculator", [
    group("addition", [
      it("adds small numbers", fn() {
        2 + 3
        |> should
        |> be_equal(5)
        |> or_fail_with("2 + 3 should equal 5")
      }),
      it("adds negative numbers", fn() {
        -2 + -3
        |> should
        |> be_equal(-5)
        |> or_fail_with("-2 + -3 should equal -5")
      }),
    ]),
    group("division", [
      it("integer division rounds toward zero", fn() {
        7 / 2
        |> should
        |> be_equal(3)
        |> or_fail_with("7 / 2 should equal 3")
      }),
    ]),
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

You’ll also see `group` used in the hook inheritance example (outer hooks apply to inner groups):

#### Hooks in nested groups <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/hooks/hook_inheritance.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{after_each, before_each, describe, group, it}
import gleam/io

pub fn tests() {
  describe("Outer", [
    before_each(fn() {
      io.println("1. outer setup")
      Ok(Nil)
    }),
    after_each(fn() {
      io.println("4. outer teardown")
      Ok(Nil)
    }),
    group("Inner", [
      before_each(fn() {
        io.println("2. inner setup")
        Ok(Nil)
      }),
      after_each(fn() {
        io.println("3. inner teardown")
        Ok(Nil)
      }),
      it("test", fn() {
        io.println("(test)")
        Ok(succeed())
      }),
    ]),
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

#### Run only the smoke tests <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/runner/filter_tests.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner.{type TestInfo}
import dream_test/unit.{describe, it, with_tags}
import gleam/list

pub fn tests() {
  describe("Filtering tests", [
    it("smoke", fn() {
      1 + 1
      |> should
      |> be_equal(2)
      |> or_fail_with("math should work")
    })
      |> with_tags(["smoke"]),
    it("slow", fn() { Ok(succeed()) })
      |> with_tags(["slow"]),
  ])
}

pub fn only_smoke(info: TestInfo) -> Bool {
  list.contains(info.tags, "smoke")
}

pub fn main() {
  runner.new([tests()])
  |> runner.filter_tests(only_smoke)
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

#### Tag a group and a test <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/unit/tagging.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### What's Next?

- Go back to [Quick Start](02-quick-start.md)
- Go back to [Documentation README](README.md)
- Continue to [Context-aware unit tests](04-context-aware-tests.md) if your setup produces a value you want to pass into every test (DB handle, client, scenario state).
