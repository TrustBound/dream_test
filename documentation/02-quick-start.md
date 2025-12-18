## Quick Start

When you’re adopting Dream Test, the first goal is simple: **write one passing test, run it, and see readable output**.

Dream Test doesn’t do “magic discovery” of test functions. You write suites explicitly, and you run them explicitly.

At a high level, the workflow is:

- Define a suite with `describe` + `it`
- Run it with `runner.new([...]) |> runner.run()`
- Add a reporter for readable output (and CI-friendly failures)

### The smallest useful setup

```gleam
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporter
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io
import gleam/string

pub fn tests() {
  describe("String utilities", [
    it("trims whitespace", fn() {
      "  hello  "
      |> string.trim()
      |> should()
      |> equal("hello")
      |> or_fail_with("Should remove surrounding whitespace")
    }),
    it("finds substrings", fn() {
      "hello world"
      |> string.contains("world")
      |> should()
      |> equal(True)
      |> or_fail_with("Should find 'world' in string")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporter.bdd(io.print, True))
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
