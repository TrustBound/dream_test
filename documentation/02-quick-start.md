## Quick Start

When you’re adopting Dream Test, the first goal is simple: **write one passing test, run it, and see readable output**.

Dream Test keeps the runner explicit on purpose. Instead of “magic test registration,” you get a tiny runner module where you decide:

- What suites to run
- What output to produce
- How CI should behave on failure

That explicitness is the source of most of Dream Test’s reliability: when a test run surprises you, there’s always a concrete `main()` you can inspect.

### Choose your first runner style

There are two good starting points. Pick the one that matches your target:

- **BEAM (Erlang target)**: use discovery to avoid maintaining an import list.
- **Portable (BEAM or JavaScript)**: list suites explicitly.

### Option A: the smallest useful setup (BEAM-only discovery)

<sub>Note: module discovery is BEAM-only. If you’re targeting JavaScript, use Option B.</sub>

```gleam
import dream_test/discover.{from_path, to_suites}
import dream_test/reporters
import dream_test/runner.{reporter, exit_on_failure, run}
import gleam/io

pub fn main() {
  let suites =
    discover.new()
    |> from_path("unit/**_test.gleam")
    |> to_suites()

  runner.new(suites)
  |> reporter(reporters.bdd(io.print, True))
  |> exit_on_failure()
  |> run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/runner/discovery_runner.gleam)</sub>

What’s happening here (in English):

- `from_path("unit/**_test.gleam")` finds test modules on disk.
- `to_suites()` turns them into suite values.
- The runner executes those suites and streams output via a reporter.

### Option B: explicit suites (simple, portable, and easy to reason about)

This is the most “teachable” version because nothing is implicit: `tests()` returns a suite, and `main()` runs it.

```gleam
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io
import gleam/string.{contains, trim}

pub fn tests() {
  describe("String utilities", [
    it("trims whitespace", fn() {
      let actual = "  hello  " |> trim()

      actual
      |> should()
      |> equal("hello")
      |> or_fail_with("Should remove surrounding whitespace")
    }),
    it("finds substrings", fn() {
      let has_world = "hello world" |> contains("world")

      has_world
      |> should()
      |> equal(True)
      |> or_fail_with("Should find 'world' in string")
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

<sub>🧪 [Tested source](../examples/snippets/test/snippets/unit/quick_start.gleam)</sub>

### Why this shape?

- **`tests()` is your suite**: it describes behavior. It should be boring to call and easy to reuse.
- **`main()` is policy**: it decides how you want output and how strict CI should be.
- **Assertions are pipes**: you start from a value, apply matchers, and end with a message you’ll be happy to see in logs.

If you only copy one idea from Dream Test, copy this one: always end an assertion chain with `or_fail_with("...")`. That message becomes the breadcrumb you’ll use when debugging.

### What's Next?

- Go back to [Installation](01-installation.md)
- Go back to [Documentation README](README.md)
- Continue to [Writing unit tests](03-writing-tests.md) to get comfortable with `describe`, `it`, grouping, skipping, and tags.
