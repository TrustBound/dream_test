## Quick Start

When you’re adopting Dream Test, the first goal is simple: **write one passing test, run it, and see readable output**.

Dream Test keeps the runner explicit: you control what runs and how it’s reported.

### The smallest useful setup (with discovery)

<sub>Note: module discovery is BEAM-only (Erlang target). If you’re targeting JavaScript, skip to the “explicit suites” example below.</sub>

```gleam
import dream_test/discover.{from_path, to_suites}
import dream_test/reporters
import dream_test/runner
import gleam/io

pub fn main() {
  let suites =
    discover.new()
    |> from_path("unit/**_test.gleam")
    |> to_suites()

  runner.new(suites)
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/runner/discovery_runner.gleam)</sub>

### Explicit suites (simple and portable)

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

- **`tests()` is your suite**: it declares what should be true.
- **`main()` is the runner**: it decides how you want to see output and how CI should behave.
- **Assertions are pipes**: you take a value, run matchers, and finish with a message you’ll actually want to read when something fails.

If you only copy one idea from Dream Test, copy this one: always end an assertion chain with `or_fail_with("...")`. That message becomes the breadcrumb you’ll use when debugging.
