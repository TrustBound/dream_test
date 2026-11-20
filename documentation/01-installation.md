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

In your own project, run:

```sh
gleam test
```

Only the Dream Test repository has a Makefile, in its top folder. The example projects have none. In the repository, `make examples` runs the tests of each example project, and `make test` runs `gleam test`:

```sh
make test
```

**Note:** `gleam test` runs the test runner module at `test/{project_name}_test.gleam` (where `project_name` matches the `name` in your `gleam.toml`). This file must define `pub fn main()`. See the `gleeunit` docs for the standard runner shape. ([hexdocs.pm/gleeunit](https://hexdocs.pm/gleeunit/index.html))

### Required: a test runner module (`pub fn main()`)

Dream Test requires an explicit runner module. This is a design choice:

- **No hidden global state**: the runner is just Gleam code you can read.
- **No surprising defaults**: your code chooses concurrency, timeouts, reporters, and CI behavior.
- **Better “why did this fail?” debugging**: you can add logging or swap reporters without rewriting tests.

Create the file `test/{project_name}_test.gleam` with a `pub fn main()`. `gleam test` runs the `main` of this file only, so it must have this name.

You can use module discovery to avoid maintaining an import list.

#### A discovery test runner <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/runner/discovery_runner.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### What you just set up

- `discover` turns files into suites (a convenience). Each discovered module must define `pub fn tests()` that returns a `TestSuite`. Discovery skips a module without it, and gives no error for it. When no module that the pattern matches has `tests()`, discovery gives the error `<pattern>: no test module matches the pattern`.
- The pattern names files under `test/`. `snippets/unit/**.gleam` is the folder of this repository's examples. In your project, use your own folder, for example `unit/**_test.gleam` for `test/unit/cart_test.gleam`.
- `runner` executes suites with isolation, timeouts, and configurable parallelism.
- `reporters` decide how results are rendered (human output vs JSON vs more).

### What's Next?

- Go back to [Documentation README](README.md)
- Continue to [Quick Start](02-quick-start.md) to write a first passing test and see the output you’ll build on.
