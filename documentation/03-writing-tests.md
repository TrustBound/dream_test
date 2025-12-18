## Writing unit tests (`describe`, `it`, `group`, `skip`, tags)

Most of the time, you want tests that read like a conversation with the code:

- “Here’s the behavior I’m testing” (`describe`)
- “Here’s one concrete thing that should be true” (`it`)

Dream Test’s unit DSL is built for that style.

### `describe` + `it` (the core loop)

```gleam
import dream_test/assertions/should.{
  be_error, be_ok, equal, or_fail_with, should,
}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io
import snippets.{add, divide}

pub fn tests() {
  describe("Calculator", [
    it("adds two numbers", fn() {
      add(2, 3)
      |> should()
      |> equal(5)
      |> or_fail_with("2 + 3 should equal 5")
    }),
    it("handles division", fn() {
      divide(10, 2)
      |> should()
      |> be_ok()
      |> equal(5)
      |> or_fail_with("10 / 2 should equal 5")
    }),
    it("returns error for division by zero", fn() {
      divide(1, 0)
      |> should()
      |> be_error()
      |> or_fail_with("Division by zero should error")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/unit/hero.gleam)</sub>

### How to think about `describe` and `it`

- Use **`describe("Thing", [...])`** to name the unit of behavior you’re testing (a module, type, feature, etc).
- Use **short `it` names** that describe the _user-visible_ outcome (“returns error for division by zero”).
- Keep `it` bodies small: arrange → act → assert. If setup is noisy, move it into helpers or hooks (next guide).

### `skip` (keep the test, don’t run it)

Use `skip` when you want to keep the test structure and body around, but temporarily disable execution.

```gleam
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it, skip}
import gleam/io
import snippets.{add}

pub fn tests() {
  describe("Skipping tests", [
    it("runs normally", fn() {
      add(2, 3)
      |> should()
      |> equal(5)
      |> or_fail_with("2 + 3 should equal 5")
    }),
    skip("not implemented yet", fn() {
      // This test is skipped - the body is preserved but not executed
      add(100, 200)
      |> should()
      |> equal(300)
      |> or_fail_with("Should add large numbers")
    }),
    it("also runs normally", fn() {
      add(0, 0)
      |> should()
      |> equal(0)
      |> or_fail_with("0 + 0 should equal 0")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/unit/skipping_tests.gleam)</sub>

### `group` (structure inside a `describe`)

Use `group` when you want nested structure inside a suite. This is often paired with hooks (see the lifecycle hooks guide).

### Tags (when you need a “slice” of a suite)

Tags are lightweight metadata on tests/groups. They become part of the `TestResult.tags` list, which you can use to filter or post-process results.

This repo also uses tags heavily in Gherkin suites (see the Gherkin guide), where tags come from `with_tags(...)` on scenarios.

```gleam
import dream_test/assertions/should.{succeed}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it, with_tags}
import gleam/io

pub fn tests() {
  describe("Tagged tests", [
    it("fast", fn() { Ok(succeed()) })
      |> with_tags(["unit", "fast"]),
    it("slow", fn() { Ok(succeed()) })
      |> with_tags(["integration", "slow"]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/unit/tagging.gleam)</sub>
