<div align="center">
  <img src="./ricky_and_lucy.png" alt="Dream Test logo" width="180">
  <h1>Dream Test</h1>
  <p><strong>A feature-rich testing framework for Gleam.</strong></p>

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

| Feature | What you get |
| --- | --- |
| **Powerful assertions + matchers** | A rich matcher library with readable, pipe-friendly assertions that keep failures explicit. |
| **Straight Gleam** | No macros or hidden runtime tricks—just Gleam modules and functions. |
| **Parallel by default** | Fast test runs with bounded concurrency, plus a single dial to go fully sequential when you need it. |
| **Crash + timeout isolation** | Each test is isolated so crashes and timeouts don’t take down the whole run. |
| **Explicit runner (with optional discovery)** | You control what runs and how it’s reported: list suites explicitly, or opt into discovery when that’s cleaner. |
| **Reporters for humans + CI** | Event-driven reporters (BDD/Progress/JSON) and post-run formatting. |
| **Context-aware tests** | Share setup and values cleanly with `unit_context` when tests need more structure than plain `describe`/`it`. |
| **Lifecycle hooks** | Compose setup/teardown with `before_*` / `after_*` hooks without turning tests into a maze. |
| **Snapshot testing** | Lock in complex output with snapshots when “assert everything” would be noisy. |
| **Gherkin BDD feature specs** | Write clear `Given/When/Then` specs that bridge product and engineering—authored as standard `.feature` files or directly in Gleam. |
| **A path from small to large** | Start with `describe`/`it`, then add contexts, hooks, snapshots, or Gherkin only when they actually help. |

It’s designed for the common case (unit + integration tests) and it scales cleanly as your suite grows (contexts, snapshots, BDD/Gherkin, CI reporting).

## Showcase (copy/paste)

If you want step-by-step setup (install + where to put the runner), start with:

- [Quick Start](documentation/02-quick-start.md)
- [Installation](documentation/01-installation.md)

### Before you copy/paste

1. Add Dream Test as a **dev dependency** in your `gleam.toml`:

```toml
[dev-dependencies]
dream_test = "~> 2.0"
```

2. Create a test runner module (this is what `gleam test` executes), e.g. `test/my_project_test.gleam`.
3. Run:

```sh
gleam test
```

### Showcase: discovery runner (BEAM-only)

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

### Showcase: explicit suites + assertions

This is the simplest thing that can work: one module exports `tests()`, and `main()` runs it.

```gleam
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporters
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
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](examples/snippets/test/snippets/unit/quick_start.gleam)</sub>

### Showcase: runner configuration (parallelism + timeouts)

Building on the `tests()` function above, you can tune parallelism and timeouts:

```gleam
import dream_test/reporters
import dream_test/runner
import gleam/io

pub fn main() {
  runner.new([tests()])
  |> runner.max_concurrency(8)
  |> runner.default_timeout_ms(10_000)
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](examples/snippets/test/snippets/runner/runner_config.gleam)</sub>

### More showcases (tested examples)

- **Snapshot testing**: [Snapshot testing example](examples/snippets/test/snippets/matchers/snapshot_testing.gleam)
- **Lifecycle hooks**: [Lifecycle hooks](examples/snippets/test/snippets/hooks/lifecycle_hooks.gleam)
- **Context-aware tests**: [Context-aware tests](examples/snippets/test/snippets/hooks/context_aware_tests.gleam)
- **Gherkin BDD**:
  - Standard `.feature` file: [Shopping cart feature](examples/shopping_cart/features/shopping_cart.feature)
  - Inline Gleam DSL: [Feature in Gleam](examples/shopping_cart/test/features/shopping_cart.gleam)
  - Runner + steps: [Example runner](examples/shopping_cart/test/shopping_cart_test.gleam) and [step definitions](examples/shopping_cart/test/steps/)

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

API reference lives on Hexdocs: `https://hexdocs.pm/dream_test/`

## Contributing

If you’re working in this repo, use the Makefile targets (tests, checks, etc.).

- `CONTRIBUTING.md`
- `STANDARDS.md`

<div align="center">
  <sub>Built in Gleam, on the BEAM, by the <a href="https://github.com/trustbound/dream">Dream Team</a>.</sub>
</div>
