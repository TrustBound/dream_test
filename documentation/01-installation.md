## Installation

### Add the dependency

Add Dream Test as a **dev dependency** in your `gleam.toml`:

```toml
[dev-dependencies]
dream_test = "~> 2.0"
```

### Run tests locally

This repo (and the examples) use a Makefile. If you’re in this repo:

```sh
make test
```

In your own project, you typically run:

```sh
gleam test
```

### Required: a test runner module (`pub fn main()`)

Dream Test does not rely on “auto-discovery” of test functions. Instead, you create one
test module with a `pub fn main()` that runs your suites.

```gleam
import dream_test/reporter
import dream_test/runner
import dream_test/unit.{describe, it}
import dream_test/assertions/should.{equal, or_fail_with, should}
import gleam/io

pub fn tests() {
  describe("Example", [
    it("works", fn() {
      1 + 1
      |> should()
      |> equal(2)
      |> or_fail_with("math should work")
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

<sub>🧪 [Tested source](../examples/snippets/test/snippets/runner/minimal_test_runner.gleam)</sub>
