## Quick Start

When you’re adopting Dream Test, the first goal is simple: **write one passing test, run it, and see readable output**.

Dream Test keeps the runner explicit on purpose. Instead of tests “just running” because a file exists or was imported, you build **suite values** and pass them to a tiny runner module where you decide:

- What suites to run
- What output to produce
- How CI should behave on failure

That explicitness is the source of most of Dream Test’s reliability: when a test run surprises you, there’s always a concrete `main()` you can inspect.

If you’re looking for a mental model of “how does the runner find my tests?”: in Dream Test, **`main()` chooses what runs** by passing suites to the runner. You can list suites explicitly, or generate the list via discovery.

### Choose your first runner style

There are two good starting points:

- **Discovery**: avoid maintaining an import list.
- **Explicit suites**: simple and easy to reason about.

### Option A: the smallest useful setup (discovery)

```gleam
import dream_test/discover.{from_path, to_suites}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner.{exit_on_failure, progress_reporter, results_reporters, run}

pub fn main() {
  let suites =
    discover.new()
    |> from_path("unit/**_test.gleam")
    |> to_suites()

  runner.new(suites)
  |> progress_reporter(progress.new())
  |> results_reporters([bdd.new()])
  |> exit_on_failure()
  |> run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/runner/discovery_runner.gleam)</sub>

What’s happening here (in English):

- `from_path("unit/**_test.gleam")` finds test modules on disk.
- `to_suites()` turns them into suite values.
- The runner executes those suites and streams output via a reporter.

### Option B: explicit suites (simple and easy to reason about)

This is the most “teachable” version because nothing is implicit: `tests()` returns a suite, and `main()` runs it.

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/string.{contains, trim}

pub fn tests() {
  describe("String utilities", [
    it("trims whitespace", fn() {
      let actual = "  hello  " |> trim()

      actual
      |> should
      |> be_equal("hello")
      |> or_fail_with("Should remove surrounding whitespace")
    }),
    it("finds substrings", fn() {
      let has_world = "hello world" |> contains("world")

      has_world
      |> should
      |> be_equal(True)
      |> or_fail_with("Should find 'world' in string")
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
