## Installation

Installation is deliberately boring. The goal is not “get the fanciest setup,” it’s:

- Get one test running locally
- Get one test running in CI
- Keep the runner **explicit**, so future changes don’t surprise you

### Add the dependency (as dev-only)

Add Dream Test as a **dev dependency** in your `gleam.toml` using `gleam add`:

```shell
gleam add --dev dream_test
```

Why dev-dependency? Tests are a build-time concern. Keeping it in `[dev-dependencies]` makes it clear Dream Test is not part of your runtime application surface area.

### Run tests locally (what command you should use)

This repo (and the examples) use a Makefile. If you’re in this repo:

```sh
make test
```

In your own project, you typically run:

```sh
gleam test
```

**Note:** `gleam test` runs the test runner module at `test/{project_name}_test.gleam` (where `project_name` matches the `name` in your `gleam.toml`). This file must define `pub fn main()`. See the `gleeunit` docs for the standard runner shape. ([hexdocs.pm/gleeunit](https://hexdocs.pm/gleeunit/index.html))

### Required: a test runner module (`pub fn main()`)

Dream Test requires an explicit runner module. This is a design choice:

- **No hidden global state**: the runner is just Gleam code you can read.
- **No surprising defaults**: your code chooses concurrency, timeouts, reporters, and CI behavior.
- **Better “why did this fail?” debugging**: you can add logging or swap reporters without rewriting tests.

Create a file under `test/` (for example, `test/{project_name}_test.gleam`) with a `pub fn main()`.

You can use module discovery to avoid maintaining an import list.

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

### What you just setup

- `discover` turns files into suites (a convenience).
- `runner` executes suites with isolation, timeouts, and configurable parallelism.
- `reporters` decide how results are rendered (human output vs JSON vs more).

### What's Next?

- Go back to [Documentation README](README.md)
- Continue to [Quick Start](02-quick-start.md) to write a first passing test and see the output you’ll build on.
