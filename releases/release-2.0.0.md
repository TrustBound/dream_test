# Dream Test 2.0.0 Release Notes

**Release Date:** 2025-12-17

Dream Test 2.0 is a **major** release that makes test execution and reporting more explicit:

- A **suite-first runner** with a pipe-friendly builder (`runner.new([suite]) |> ... |> runner.run()`).
- **Split reporting**: a live **progress reporter** during the run, and one or more
  deterministic **results reporters** printed at the end.
- **Result-returning tests + hooks**: test bodies and lifecycle hooks return `Result(..., String)`, enabling clean multi-step setup with `use <- result.try(...)`.
- A unified public assertions surface under `dream_test/matchers`.
- Clearer, safer behavior for hooks, timeouts, and crashes (with optional crash reports).
- **Suite-specific execution config**: run some suites sequentially / with different timeouts in the same runner via `runner.add_suites_with_config(...)`.

## Why Dream Test 2.0?

Dream Test 2.0 is mostly about **reducing surprise** in real-world suites (parallel execution, multi-step setup, CI logs) by making the framework's "execution model" explicit and composable.

What we were fixing:

- **Hidden control flow** in tests with multi-step setup. In 1.x, tests often needed extra boilerplate to bail early with a useful message.
- **Output that gets confusing under parallelism**. When many tests finish out of order, "nice output" requires an explicit event model so reporters can stay deterministic.
- **Friction around wiring suites**. Manually maintaining import lists is tedious and error-prone as a codebase grows.

What we wanted in 2.0:

- **Linear, readable multi-step tests**: test bodies and hooks return `Result(_, String)` so you can use `use <- result.try(...)` and early-exit with a human error message.
- **A single "runner pipeline"**: your `main()` becomes the policy surface (parallelism, timeouts, filtering, reporting, CI exit codes).
- **Reporters driven by structured events**: output becomes reliable even when execution is concurrent.
- **Optional discovery** for teams that prefer not to maintain explicit suite lists.

## Highlights

### ✅ Runner: suite-first builder (`dream_test/runner`)

**Why this change:** in 1.x, "how tests run" was spread across helpers and defaults. In 2.0, `main()` is the explicit policy surface: you can read one pipeline and know concurrency, timeouts, filtering, reporting, and CI behavior.

The runner is now a single, explicit pipeline:

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Example", [
    it("works", fn() {
      1 + 1
      |> should
      |> be_equal(2)
      |> or_fail_with("math should work")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.max_concurrency(8)
  |> runner.default_timeout_ms(10_000)
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

Runner builder functions:

| Function                          | Purpose                                 | Default     |
| --------------------------------- | --------------------------------------- | ----------- |
| `runner.new([suite])`             | Creates a `RunBuilder(ctx)`             | —           |
| `runner.max_concurrency(n)`       | Controls parallelism (`1` = sequential) | `50`        |
| `runner.default_timeout_ms(ms)`   | Default timeout for tests               | `5000` (5s) |
| `runner.progress_reporter(...)`   | Live progress during the run            | None        |
| `runner.results_reporters([...])` | End-of-run reporters                    | `[]`        |
| `runner.filter_tests(predicate)`  | Pre-execution filtering                 | None        |
| `runner.exit_on_failure()`        | Exit with code 1 on failure             | Disabled    |
| `runner.run()`                    | Execute and return `List(TestResult)`   | —           |

### ✅ Result-returning tests + hooks

**Why this change:** multi-step tests are common (fixtures → setup → assertions). Returning `Result(_, String)` lets tests stay linear, and lets failures carry a human explanation without forcing extra plumbing.

In v2, **tests return `Result(AssertionResult, String)`** and **hooks return `Result(ctx, String)`**. You can bail out early with `Error("...")`, and the runner will record it as a failure with that message.

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/result

fn load_config() -> Result(String, String) {
  // Setup helpers should return Result(_, String) so result.try stays clean.
  Ok("config loaded")
}

fn connect_db(config: String) -> Result(String, String) {
  case config {
    "" -> Error("config was empty")
    _ -> Ok("db connected")
  }
}

pub fn tests() {
  describe("Multi-step setup", [
    it("can short-circuit with a message", fn() {
      use config <- result.try(load_config())
      use db_status <- result.try(connect_db(config))

      db_status
      |> should
      |> be_equal("db connected")
      |> or_fail_with("database should connect")
    }),
  ])
}
```

### 📣 Reporting: progress + results reporters

**Why this change:** parallel execution means completion order is not declaration order. Dream Test splits reporting so live progress can react to completion order, while final reports are printed in traversal order (deterministic).

This is a **full refactor** of reporting in 2.0:

- During the run, the runner emits structured events (`dream_test/reporters/types.ReporterEvent`) so live UIs can update.
- At the end of the run, the runner hands the **full traversal-ordered results** to one or more **results reporters**.
- The runner owns output routing via `runner.output(...)` / `runner.silent()`.

The runner emits these events:

| Event                                    | When                                   |
| ---------------------------------------- | -------------------------------------- |
| `RunStarted(total)`                      | Run begins                             |
| `TestFinished(completed, total, result)` | Each test completes (completion order) |
| `HookStarted(...)` / `HookFinished(...)` | Lifecycle hooks run                    |
| `RunFinished(completed, total, results)` | Run ends (results in traversal order)  |

Built-in reporters:

| Reporter         | Purpose                          | Configuration                                        |
| ---------------- | -------------------------------- | ---------------------------------------------------- |
| `progress.new()` | Live progress bar during run     | —                                                    |
| `bdd.new()`      | Human-readable BDD report at end | `bdd.color`, `bdd.failures_only`, `bdd.summary_only` |
| `json.new()`     | Machine-readable JSON at end     | `json.pretty`                                        |

Notes:

- The **BDD reporter now also formats Gherkin scenarios** (Feature → Scenario layout) when results include `GherkinScenario(_)`.
- Use **progress + bdd** for local dev; use **json** for CI/tooling.

### 🧯 Sandbox: optional crash reports (`dream_test/sandbox`)

**Why this change:** crash reports are useful when debugging locally, but noisy in CI. 2.0 keeps crash isolation while letting you opt into crash logs when you need them.

- `SandboxConfig(show_crash_reports: False)` suppresses `=CRASH REPORT====` output (default).
- `sandbox.with_crash_reports(config)` enables crash reports for local debugging.

---

## Breaking changes & migration guide

If you're upgrading from Dream Test 1.x → 2.0, follow these steps in order. Most projects can upgrade in **10–20 minutes**.

### Removed and renamed APIs

| 1.x API                                                        | 2.0 replacement                                                 |
| -------------------------------------------------------------- | --------------------------------------------------------------- |
| `dream_test/assertions/should`                                 | `dream_test/matchers`                                           |
| `dream_test/reporter`                                          | `dream_test/reporters/bdd`, `dream_test/reporters/json`, etc.   |
| `run_all(test_cases)`                                          | `runner.new([suite]) \|> runner.run()`                          |
| `run_suite(suite)`                                             | `runner.new([suite]) \|> runner.run()`                          |
| `to_test_cases(suite)`                                         | No longer needed; pass suites directly to `runner.new(...)`     |
| `report(results, io.print)`                                    | `runner.results_reporters([bdd.new()])`                         |
| `exit_on_failure(results)`                                     | `runner.exit_on_failure()` (call before `run()`)                |
| `RunnerConfig { ... }`                                         | Builder functions: `runner.max_concurrency(...)`, etc.          |
| (new) run suites with different concurrency/timeout in one run | `runner.add_suites(...)` + `runner.add_suites_with_config(...)` |
| Test body returns `AssertionResult`                            | Test body returns `Result(AssertionResult, String)`             |
| Hook body returns `ctx`                                        | Hook body returns `Result(ctx, String)`                         |
| `world.get` returns `Result(a, Nil)`                           | `world.get` returns `Result(a, String)`                         |

### Step 1: bump the dependency

```toml
[dev-dependencies]
dream_test = "~> 2.0"
```

```bash
gleam deps download
```

### Step 2: update imports and runner entrypoint

Replace your 1.x runner with the v2 builder pipeline:

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Example", [
    it("works", fn() {
      1 + 1
      |> should
      |> be_equal(2)
      |> or_fail_with("math should work")
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

For colored BDD + pretty JSON output:

```gleam
runner.new([tests()])
|> runner.progress_reporter(progress.new())
|> runner.results_reporters([
  bdd.new() |> bdd.color,
  json.new() |> json.pretty,
])
|> runner.exit_on_failure()
|> runner.run()
```

### Step 3: update test bodies to return `Result(_, String)`

- **Most matcher chains already work**: `... |> or_fail_with("...")` returns `Result(AssertionResult, String)`.
- If you used `succeed()` / `fail_with(...)` in a branch, wrap it in `Ok(...)`.
- If setup should abort immediately, return `Error("message")`.

```gleam
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should, succeed}
import dream_test/unit.{describe, it}
import gleam/result

pub fn tests() {
  describe("Result-returning tests", [
    // 1) Matcher chain (no change needed)
    it("matcher chain", fn() {
      "hello"
      |> should
      |> be_equal("hello")
      |> or_fail_with("strings should match")
    }),

    // 2) Branchy logic: wrap in Ok(...)
    it("branchy logic", fn() {
      Ok(case True {
        True -> succeed()
        False -> fail_with("expected True")
      })
    }),

    // 3) Multi-step setup: use result.try
    it("multi-step", fn() {
      use value <- result.try(Ok("setup done"))
      value
      |> should
      |> be_equal("setup done")
      |> or_fail_with("setup should complete")
    }),
  ])
}
```

### Step 4: update hooks to return `Result(ctx, String)`

Hooks now return `Result(ctx, String)` so they can fail with a message:

```gleam
import dream_test/matchers.{succeed}
import dream_test/unit.{before_each, describe, it}

pub fn tests() {
  describe("With hooks", [
    before_each(fn() {
      // Return Ok(Nil) on success, Error("message") on failure
      Ok(Nil)
    }),
    it("runs after setup", fn() {
      Ok(succeed())
    }),
  ])
}
```

For context-aware tests (`dream_test/unit_context`):

```gleam
import dream_test/unit_context.{before_each, describe, it}

pub fn tests() {
  describe(
    "With context",
    fn() { Ok("initial context") },  // seed returns Result
    [
      before_each(fn(ctx) {
        // Transform context, return Result(new_ctx, String)
        Ok(ctx <> " + setup")
      }),
      it("has context", fn(ctx) {
        ctx
        |> should
        |> be_equal("initial context + setup")
        |> or_fail_with("context should be threaded")
      }),
    ],
  )
}
```

### Step 5 (optional): migrate filtering to `runner.filter_tests`

Filtering now happens **before execution**, so skipped subtrees don't run hooks.

```gleam
import dream_test/runner.{type TestInfo}
import gleam/list

pub fn only_smoke(info: TestInfo) -> Bool {
  list.contains(info.tags, "smoke")
}

pub fn main() {
  runner.new([tests()])
  |> runner.filter_tests(only_smoke)
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.run()
}
```

### Step 6 (optional): use discovery instead of explicit imports

If you have many test modules, discovery removes the manual import burden:

```gleam
import dream_test/discover
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner

pub fn main() {
  let suites =
    discover.new()
    |> discover.from_path("unit/**_test.gleam")
    |> discover.to_suites()

  runner.new(suites)
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

Notes:

- `from_path("unit/**_test.gleam")` is a module path glob under `./test/`.
- Discovery loads modules that export `tests/0` returning `TestSuite(Nil)`.
- Requires compiled BEAM modules (run `gleam build` first).

### Step 7 (if you use Gherkin): update `world.get` calls

`world.get` now returns `Result(a, String)` instead of `Result(a, Nil)`:

```gleam
// 1.x
case world.get(context.world, "count") {
  Ok(count) -> ...
  Error(Nil) -> Error("count not found")  // had to add message manually
}

// 2.0
case world.get(context.world, "count") {
  Ok(count) -> ...
  Error(message) -> Error(message)  // message is already a String
}
```

---

## Documentation

- [Quick Start](../documentation/02-quick-start.md)
- [Runner & Execution](../documentation/07-runner-and-execution.md)
- [Reporters](../documentation/08-reporters.md)
- [Utilities (sandbox)](../documentation/11-utilities.md)
- [CHANGELOG](../CHANGELOG.md)
