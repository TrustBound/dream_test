## Quick Start

When you’re adopting Dream Test, the first goal is simple: **write one passing test, run it, and see readable output**.

Dream Test keeps the runner explicit on purpose. Instead of tests “just running” because a file exists or was imported, you build **suite values** and pass them to a tiny runner module where you decide:

- What suites to run
- What output to produce
- How CI should behave on failure

That explicitness is the source of most of Dream Test’s reliability: when a test run surprises you, there’s always a concrete `main()` you can inspect.

If you’re looking for a mental model of “how does the runner find my tests?”: in Dream Test, **`main()` chooses what runs** by passing suites to the runner. You can list suites explicitly, or generate the list via discovery.

If you need setup/teardown that spans multiple suites, see the runner-level hooks section in [Runner & execution model](07-runner-and-execution.md).

### Choose your first runner style

There are two good starting points:

- **Discovery**: avoid maintaining an import list.
- **Explicit suites**: simple and easy to reason about.

### Option A: the smallest useful setup (discovery)

#### Discover test modules <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/runner/discovery_runner.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/discover.{from_path, to_suites}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner.{
  exit_on_failure, progress_reporter, results_reporters, run,
}

pub fn main() {
  runner.new(suites())
  |> progress_reporter(progress.new())
  |> results_reporters([bdd.new()])
  |> exit_on_failure()
  |> run()
}

/// The suites of every test module under `test/snippets/unit/`.
pub fn suites() {
  discover.new()
  |> from_path("snippets/unit/**.gleam")
  |> to_suites()
}
```

What’s happening here (in English):

- `from_path("snippets/unit/**.gleam")` finds test modules on disk, relative to `test/`. `snippets/unit` is the folder of this repository's examples. Use your own folder, for example `unit/**_test.gleam`.
- Each discovered module must define `pub fn tests()` that returns a `TestSuite`. Discovery skips a module without it, and gives no error for it.
- `to_suites()` turns them into suite values. A module can return any suite: a `unit` suite, a `unit_context` suite with its own context, or a Gherkin feature.
- The runner executes those suites and streams output via a reporter.

### Option B: explicit suites (simple and easy to reason about)

This is the most “teachable” version because nothing is implicit: `tests()` returns a suite, and `main()` runs it.

#### Explicit suites <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/unit/quick_start.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/string

pub fn tests() {
  describe("String utilities", [
    it("trims whitespace", fn() {
      "  hello  "
      |> string.trim()
      |> should
      |> be_equal("hello")
      |> or_fail_with("Should remove surrounding whitespace")
    }),
    it("finds substrings", fn() {
      "hello world"
      |> string.contains("world")
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

### Why this shape?

- **`tests()` is your suite**: it describes behavior. It should be boring to call and easy to reuse.
- **`main()` is policy**: it decides how you want output and how strict CI should be.
- **Assertions are pipes**: you start from a value, apply matchers, and end with a message you’ll be happy to see in logs.

If you only copy one idea from Dream Test, copy this one: always end an assertion chain with `or_fail_with("...")`. That message becomes the breadcrumb you’ll use when debugging.

### What's Next?

- Go back to [Installation](01-installation.md)
- Go back to [Documentation README](README.md)
- Continue to [Writing unit tests](03-writing-tests.md) to get comfortable with `describe`, `it`, grouping, skipping, and tags.
