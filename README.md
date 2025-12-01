<div align="center">
  <img src="https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png" alt="Dream Logo" width="180">
  <h1>Dream Test</h1>
  <p><strong>A testing framework for Gleam that gets out of your way.</strong></p>

  <a href="https://hex.pm/packages/dream_test">
    <img src="https://img.shields.io/hexpm/v/dream_test?color=8e4bff&label=hex" alt="Hex.pm">
  </a>
  <a href="https://hexdocs.pm/dream_test/">
    <img src="https://img.shields.io/badge/docs-hexdocs-8e4bff" alt="Documentation">
  </a>
  <a href="https://github.com/TrustBound/dream_test/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue" alt="License">
  </a>
</div>

<br>

```gleam
import dream_test/unit.{describe, it}
import dream_test/assertions/should.{be_error, be_ok, equal, or_fail_with, should}

pub fn tests() {
  describe("Calculator", [
    it("adds two numbers", fn() {
      add(2, 3)
      |> should()
      |> equal(5)
      |> or_fail_with("2 + 3 should equal 5")
    }),
    it("handles division", fn() {
      divide(10, 2)
      |> should()
      |> be_ok()
      |> equal(5)
      |> or_fail_with("10 / 2 should equal 5")
    }),
    it("returns error for division by zero", fn() {
      divide(1, 0)
      |> should()
      |> be_error()
      |> or_fail_with("Division by zero should error")
    }),
  ])
}
```

```
Calculator
  ✓ adds two numbers
  ✓ handles division
  ✓ returns error for division by zero

3 tests, 0 failures
```

<sub>🧪 [Tested source](examples/snippets/test/hero.gleam)</sub>

---

## Installation

```toml
# gleam.toml
[dev-dependencies]
dream_test = "~> 1.0"
```

---

## Why Dream Test?

| Feature                 | What you get                                                                   |
| ----------------------- | ------------------------------------------------------------------------------ |
| **Parallel by default** | Tests run concurrently across all cores—100 tests finish ~4x faster on 4 cores |
| **Crash-proof**         | Each test runs in an isolated BEAM process; one crash doesn't kill the suite   |
| **Timeout-protected**   | Hanging tests get killed automatically; no more stuck CI pipelines             |
| **Lifecycle hooks**     | `before_all`, `before_each`, `after_each`, `after_all` for setup/teardown      |
| **Gleam-native**        | Pipe-first assertions that feel natural; no macros, no reflection, no magic    |
| **Familiar syntax**     | If you've used Jest, RSpec, or Mocha, you already know the basics              |
| **Type-safe**           | Your tests are just Gleam code; the compiler catches mistakes early            |
| **Self-hosting**        | Dream Test tests itself; we eat our own cooking                                |

---

## Quick Start

### 1. Write tests with `describe` and `it`

```gleam
// test/my_app_test.gleam
import dream_test/unit.{describe, it, to_test_cases}
import dream_test/runner.{run_all}
import dream_test/reporter/bdd.{report}
import dream_test/assertions/should.{should, equal, or_fail_with}
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
  to_test_cases("my_app_test", tests())
  |> run_all()
  |> report(io.print)
}
```

<sub>🧪 [Tested source](examples/snippets/test/quick_start.gleam)</sub>

### 2. Run with gleam test

```sh
gleam test
```

### 3. See readable output

```
String utilities
  ✓ trims whitespace
  ✓ finds substrings

2 tests, 0 failures
```

---

## The Assertion Pattern

Every assertion follows the same pattern:

```gleam
value |> should() |> matcher() |> or_fail_with("message")
```

### Chaining matchers

Matchers can be chained. Each one passes its unwrapped value to the next:

```gleam
// Unwrap Some, then check the value
Some(42)
|> should()
|> be_some()
|> equal(42)
|> or_fail_with("Should contain 42")

// Unwrap Ok, then check the value
Ok("success")
|> should()
|> be_ok()
|> equal("success")
|> or_fail_with("Should be Ok with 'success'")
```

<sub>🧪 [Tested source](examples/snippets/test/chaining.gleam)</sub>

### Available matchers

| Category        | Matchers                                                                                    |
| --------------- | ------------------------------------------------------------------------------------------- |
| **Equality**    | `equal`, `not_equal`                                                                        |
| **Boolean**     | `be_true`, `be_false`                                                                       |
| **Option**      | `be_some`, `be_none`                                                                        |
| **Result**      | `be_ok`, `be_error`                                                                         |
| **Collections** | `contain`, `not_contain`, `have_length`, `be_empty`                                         |
| **Comparison**  | `be_greater_than`, `be_less_than`, `be_at_least`, `be_at_most`, `be_between`, `be_in_range` |
| **String**      | `start_with`, `end_with`, `contain_string`                                                  |

### Explicit failures

When you need to fail unconditionally:

```gleam
import dream_test/assertions/should.{fail_with}

case result {
  Ok(_) -> fail_with("Should have returned an error")
  Error(_) -> handle_expected_error()
}
```

<sub>🧪 [Tested source](examples/snippets/test/explicit_failures.gleam)</sub>

### Skipping tests

Use `skip` instead of `it` to temporarily disable a test:

```gleam
import dream_test/unit.{describe, it, skip}

describe("Feature", [
  it("works correctly", fn() { ... }),
  skip("not implemented yet", fn() { ... }),  // Skipped
  it("handles edge cases", fn() { ... }),
])
```

```
Feature
  ✓ works correctly
  - not implemented yet
  ✓ handles edge cases

Summary: 3 run, 0 failed, 2 passed, 1 skipped
```

The test body is preserved but not executed—just change `skip` back to `it` when ready.

<sub>🧪 [Tested source](examples/snippets/test/skipping_tests.gleam)</sub>

---

## Lifecycle Hooks

Setup and teardown logic for your tests. Dream_test supports four lifecycle hooks
that let you run code before and after tests.

```gleam
import dream_test/unit.{describe, it, before_each, after_each, before_all, after_all}
import dream_test/types.{AssertionOk}

describe("Database tests", [
  before_all(fn() {
    start_database()
    AssertionOk
  }),

  before_each(fn() {
    begin_transaction()
    AssertionOk
  }),

  it("creates a user", fn() { ... }),
  it("deletes a user", fn() { ... }),

  after_each(fn() {
    rollback_transaction()
    AssertionOk
  }),

  after_all(fn() {
    stop_database()
    AssertionOk
  }),
])
```

<sub>🧪 [Tested source](examples/snippets/test/lifecycle_hooks.gleam)</sub>

### Hook Types

| Hook          | Runs                              | Use case                          |
| ------------- | --------------------------------- | --------------------------------- |
| `before_all`  | Once before all tests in group    | Start services, create temp files |
| `before_each` | Before each test                  | Reset state, begin transaction    |
| `after_each`  | After each test (even on failure) | Rollback, cleanup temp data       |
| `after_all`   | Once after all tests in group     | Stop services, remove temp files  |

### Two Execution Modes

Choose the mode based on which hooks you need:

| Mode  | Function                      | Hooks supported             |
| ----- | ----------------------------- | --------------------------- |
| Flat  | `to_test_cases` → `run_all`   | `before_each`, `after_each` |
| Suite | `to_test_suite` → `run_suite` | All four hooks              |

**Flat mode** — simpler, faster; use when you only need per-test setup:

```gleam
import dream_test/unit.{describe, it, before_each, to_test_cases}
import dream_test/runner.{run_all}

to_test_cases("my_test", tests())
|> run_all()
|> report(io.print)
```

**Suite mode** — preserves group structure; use when you need once-per-group setup:

```gleam
import dream_test/unit.{describe, it, before_all, after_all, to_test_suite}
import dream_test/runner.{run_suite}

to_test_suite("my_test", tests())
|> run_suite()
|> report(io.print)
```

<sub>🧪 [Tested source](examples/snippets/test/execution_modes.gleam)</sub>

### Hook Inheritance

Nested `describe` blocks inherit parent hooks. Hooks run outer-to-inner for
setup, inner-to-outer for teardown:

```gleam
describe("Outer", [
  before_each(fn() {
    io.println("1. outer setup")
    AssertionOk
  }),
  after_each(fn() {
    io.println("4. outer teardown")
    AssertionOk
  }),
  describe("Inner", [
    before_each(fn() {
      io.println("2. inner setup")
      AssertionOk
    }),
    after_each(fn() {
      io.println("3. inner teardown")
      AssertionOk
    }),
    it("test", fn() {
      io.println("(test)")
      AssertionOk
    }),
  ]),
])
// Output: 1. outer setup → 2. inner setup → (test) → 3. inner teardown → 4. outer teardown
```

<sub>🧪 [Tested source](examples/snippets/test/hook_inheritance.gleam)</sub>

### Hook Failure Behavior

If a hook fails, Dream Test handles it gracefully:

| Failure in    | Result                                            |
| ------------- | ------------------------------------------------- |
| `before_all`  | All tests in group marked `SetupFailed`, skipped  |
| `before_each` | That test marked `SetupFailed`, skipped           |
| `after_each`  | Test result preserved; hook failure recorded      |
| `after_all`   | Hook failure recorded; all test results preserved |

```gleam
describe("Handles failures", [
  before_all(fn() {
    case connect_to_database() {
      Ok(_) -> AssertionOk
      Error(e) -> fail_with("Database connection failed: " <> e)
    }
  }),
  // If before_all fails, these tests are marked SetupFailed (not run)
  it("test1", fn() { AssertionOk }),
  it("test2", fn() { AssertionOk }),
])
```

<sub>🧪 [Tested source](examples/snippets/test/hook_failure.gleam)</sub>

---

## BEAM-Powered Test Isolation

Every test runs in its own BEAM process:

| Feature                | What it means                                                |
| ---------------------- | ------------------------------------------------------------ |
| **Crash isolation**    | A `panic` in one test doesn't affect others                  |
| **Timeout handling**   | Slow tests get killed; suite keeps running                   |
| **Parallel execution** | Tests run concurrently (configurable)                        |
| **Automatic cleanup**  | Resources linked to the test process are freed automatically |

```gleam
// This test crashes, but others keep running
it("handles edge case", fn() {
  panic as "oops"  // Other tests still execute and report
})

// This test hangs, but gets killed after timeout
it("fetches data", fn() {
  infinite_loop()  // Killed after 5 seconds (default)
})
```

### Configuring execution

```gleam
import dream_test/runner.{run_all_with_config, RunnerConfig}

let config = RunnerConfig(
  max_concurrency: 8,
  default_timeout_ms: 10_000,
)

let test_cases = to_test_cases("my_test", tests())
run_all_with_config(config, test_cases)
|> report(io.print)
```

<sub>🧪 [Tested source](examples/snippets/test/runner_config.gleam)</sub>

---

## How It Works

Dream_test uses an explicit pipeline—no hidden globals, no magic test discovery.

### Flat Mode (most common)

```
describe/it  →  to_test_cases  →  run_all  →  report
   (DSL)         (flatten)       (execute)   (format)
```

1. **Define** tests with `describe`/`it` — builds a test tree
2. **Convert** with `to_test_cases` — flattens to runnable cases
3. **Run** with `run_all` — executes in parallel with isolation
4. **Report** with your choice of formatter — outputs results

### Suite Mode (for `before_all`/`after_all`)

```
describe/it  →  to_test_suite  →  run_suite  →  report
   (DSL)         (preserve)       (execute)    (format)
```

Suite mode preserves the group hierarchy so hooks can run at group boundaries.

### Under the Hood

Each test runs in its own BEAM process:

```mermaid
flowchart TB
    runner[Test Runner]
    runner --> t1[Test 1]
    runner --> t2[Test 2]
    runner --> t3[Test 3]
    runner --> t4[Test 4]
    t1 --> collect[Collect Results]
    t2 --> collect
    t3 --> collect
    t4 --> collect
    collect --> report[Report]
```

Benefits:

- A crashing test doesn't affect others
- Timeouts are enforced via process killing
- Resources linked to test processes are cleaned up automatically

---

## Documentation

| Document                                      | Audience                    |
| --------------------------------------------- | --------------------------- |
| **[Hexdocs](https://hexdocs.pm/dream_test/)** | API reference with examples |
| **[CONTRIBUTING.md](CONTRIBUTING.md)**        | How to contribute           |
| **[STANDARDS.md](STANDARDS.md)**              | Coding conventions          |

---

## Status

**Stable** — v1.0 release. API is stable and ready for production use.

| Feature                           | Status    |
| --------------------------------- | --------- |
| Core DSL (`describe`/`it`/`skip`) | ✅ Stable |
| Lifecycle hooks                   | ✅ Stable |
| Assertions (`should.*`)           | ✅ Stable |
| BDD Reporter                      | ✅ Stable |
| Parallel execution                | ✅ Stable |
| Process isolation                 | ✅ Stable |
| Crash handling                    | ✅ Stable |
| Timeout handling                  | ✅ Stable |
| Polling helpers                   | ✅ Stable |

---

## Contributing

```sh
git clone https://github.com/TrustBound/dream_test
cd dream_test
make all  # build, test, format
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for development workflow and guidelines.

---

## License

MIT — see [LICENSE.md](LICENSE.md)

---

<div align="center">
  <sub>Part of the <a href="https://github.com/TrustBound/dream">Dream</a> ecosystem for Gleam</sub>
  <br>
  <sub>Built in Gleam, on the BEAM, by the Dream Team ❤️</sub>
</div>
