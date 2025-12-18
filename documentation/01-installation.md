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

Dream Test uses a test runner module with a `pub fn main()` that runs your suites.

Create a file under `test/` (for example, `test/my_project_test.gleam`) with a `pub fn main()`.

If you’re using the BEAM (Erlang target), you can use module discovery to avoid maintaining an import list.

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
