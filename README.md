<div align="center">
  <img src="./ricky_and_lucy.png" alt="Dream Test logo" width="180">
  <h1>Dream Test</h1>
  <p><strong>Testing for Gleam. Parallel by default. No magic.</strong></p>

  <a href="https://hex.pm/packages/dream_test">
    <img src="https://img.shields.io/hexpm/v/dream_test?color=8e4bff&label=hex" alt="Hex.pm">
  </a>
  <a href="https://hexdocs.pm/dream_test/">
    <img src="https://img.shields.io/badge/docs-hexdocs-8e4bff" alt="Documentation">
  </a>
  <a href="./LICENSE.md">
    <img src="https://img.shields.io/badge/license-MIT-blue" alt="License">
  </a>
</div>

<br>

## What is Dream Test?

Dream Test is a **testing framework for Gleam** that feels like Gleam:

- **Pipe-first assertions** that read top-to-bottom (the value flows through the pipeline)
- **Parallel execution by default** (and a single dial to go fully sequential when you need it)
- **Crash + timeout isolation** so one bad test doesn’t wreck the whole run
- **No surprises**: you can list suites explicitly, or opt into discovery when that’s cleaner

It’s designed for the common case (unit tests) and it doesn’t get weird when your suite gets real (contexts, snapshots, BDD/Gherkin, CI reporting).

## What Dream Test is built for

- **Straight Gleam**: no macros or hidden runtime tricks—just Gleam modules and functions.
- **Parallel by default**: tests run in parallel with bounded concurrency (default `max_concurrency` is `4`).
- **Crash + timeout isolation**: each test runs in a sandboxed process and can time out (default `5000ms`), so failures don’t take the whole run down.
- **Good output for humans and CI**: event-driven reporters (BDD/Progress/JSON) and post-run formatting.
- **A path from small to large**: start with `describe`/`it`, and add hooks, contexts, snapshots, or Gherkin only when they actually help.

## Quick start (copy/paste)

Dream Test keeps the runner explicit: you always control what runs and how it’s reported.

### Quick start: discovery

<sub>Note: module discovery is BEAM-only (Erlang target).</sub>

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

<sub>🧪 [Tested source](examples/snippets/test/snippets/runner/discovery_runner.gleam)</sub>

### Alternative: list suites explicitly

This is the simplest thing that can work: one module exports `tests()`, and `main()` runs it.

```gleam
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io
import gleam/string.{trim}

pub fn tests() {
  describe("String utilities", [
    it("trims whitespace", fn() {
      let actual = "  hello  " |> trim()

      actual
      |> should()
      |> equal("hello")
      |> or_fail_with("Should remove surrounding whitespace")
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

<sub>🧪 [Tested source](examples/snippets/test/snippets/unit/quick_start.gleam)</sub>

## Guides (start here)

If you’re new to Dream Test, this is the shortest path from “it runs” to “it scales”.

1. [Installation](documentation/01-installation.md)
2. [Quick Start](documentation/02-quick-start.md)
3. [Writing unit tests (`describe`/`it`/`group`/`skip`)](documentation/03-writing-tests.md)
4. [Context-aware tests (`unit_context`)](documentation/04-context-aware-tests.md)
5. [Assertions & matchers (the `should()` pipeline)](documentation/05-assertions-and-matchers.md)
6. [Lifecycle hooks (`before_*` / `after_*`)](documentation/06-lifecycle-hooks.md)
7. [Runner & execution model (parallelism, timeouts, CI)](documentation/07-runner-and-execution.md)
8. [Reporters (BDD, JSON, Progress, Gherkin)](documentation/08-reporters.md)
9. [Snapshot testing](documentation/09-snapshot-testing.md)
10. [Gherkin BDD (Given/When/Then, placeholders, discovery)](documentation/10-gherkin-bdd.md)
11. [Utilities (file/process/timing/sandbox helpers)](documentation/11-utilities.md)

## Installation

Add Dream Test as a **dev dependency** in your `gleam.toml`:

```toml
[dev-dependencies]
dream_test = "~> 2.0"
```

Create a test runner module (this is what `gleam test` executes). For example: `test/my_project_test.gleam`:

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

<sub>🧪 [Tested source](examples/snippets/test/snippets/runner/discovery_runner.gleam)</sub>

Then run:

```sh
gleam test
```

More detail lives here: [Installation](documentation/01-installation.md).

API reference lives on Hexdocs: `https://hexdocs.pm/dream_test/`

## Contributing

If you’re working in this repo, use the Makefile targets (tests, checks, etc.).

- `CONTRIBUTING.md`
- `STANDARDS.md`

<div align="center">
  <sub>Built in Gleam, on the BEAM, by the <a href="https://github.com/trustbound/dream">Dream Team</a>.</sub>
</div>
