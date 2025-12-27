# Dream Test 2.0.0 Release Notes

**Release Date:** 2025-12-17

Dream Test 2.0 is a **major** release that makes test execution and reporting more explicit:

- A **suite-first runner** with a pipe-friendly builder (`runner.new([suite]) |> ... |> runner.run()`).
- **Split reporting**: a live **progress reporter** during the run, and one or more
  deterministic **results reporters** printed at the end.
- **Result-returning tests + hooks**: test bodies and lifecycle hooks can return `Result(..., String)`, which enables clean multi-step setup using `use <- result.try(...)` (no more awkward “wrap everything in a `let result = { ... }` block” patterns).
- A unified public assertions surface under `dream_test/matchers`.
- Clearer, safer behavior for hooks, timeouts, and crashes (with optional crash reports).

## Why Dream Test 2.0?

Dream Test 2.0 is mostly about **reducing surprise** in real-world suites (parallel execution, multi-step setup, CI logs) by making the framework’s “execution model” explicit and composable.

What we were fixing:

- **Hidden control flow** in tests with multi-step setup. In 1.x, tests often needed extra boilerplate (including “wrap everything in a `let result = { ... }` block”) to keep setup steps readable and to bail early with a useful message.
- **Output that gets confusing under parallelism**. When many tests finish out of order, “nice output” requires an explicit event model so reporters can stay deterministic.
- **Friction around wiring suites**. Manually maintaining import lists (or relying on implicit file/module behavior) is tedious and easy to get wrong as a codebase grows.

What we wanted in 2.0:

- **Linear, readable multi-step tests**: test bodies and hooks return `Result(_, String)` so you can use `use <- result.try(...)` and early-exit with a human error message.
- **A single “runner pipeline”**: your `main()` becomes the policy surface (parallelism, timeouts, filtering, reporting, CI exit codes).
- **Reporters driven by structured events**: output becomes reliable even when execution is concurrent.
- **Optional discovery** for teams that prefer not to maintain explicit suite lists.

## Highlights

### ✅ Runner: suite-first builder (`dream_test/runner`)

**Why this change:** in 1.x, “how tests run” tended to be spread across helpers and defaults. In 2.0, `main()` is the explicit policy surface: you can read one pipeline and know concurrency, timeouts, filtering, reporting, and CI behavior.

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

Key pieces:

- `runner.new([suite])` creates a `RunBuilder(ctx)`
- `runner.max_concurrency(n)` controls parallelism (use `1` for fully sequential)
- `runner.default_timeout_ms(ms)` applies a default timeout to tests without one
- `runner.exit_on_failure()` halts the BEAM with a non-zero code if failures occurred
- `runner.filter_tests(predicate)` filters **what executes** (pre-execution)
- `runner.run()` executes and returns `List(types.TestResult)`

### ✅ Result-returning tests + hooks (multi-step setup without awkward blocks)

**Why this change:** multi-step tests are common (fixtures → setup → assertions). Returning `Result(_, String)` lets tests stay linear, and lets failures carry a human explanation without forcing extra plumbing.

In v2, **tests return `Result(AssertionResult, String)`** (and hooks return `Result(..., String)` too). This is a big quality-of-life improvement for tests with multi-step setup: you can bail out early with `Error("...")`, and the runner will record it as a failure with that message.

Because the error type is a **`String`**, you can use `use <- result.try(...)` to keep multi-step setup linear and readable.

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/result

fn load_fixture() -> Result(Fixture, String) {
  // Your setup helpers should return Result(_, String) so `result.try` stays clean.
  Error("not implemented")
}

fn start_service(_fixture: Fixture) -> Result(Service, String) {
  Error("not implemented")
}

pub fn tests() {
  describe("Multi-step setup", [
    it("can short-circuit with a message", fn() {
      // Step 1 / 2: setup that can fail, with early-return on Error(String)
      use fixture <- result.try(load_fixture())
      use service <- result.try(start_service(fixture))

      // Step 3: assertions
      service.status
      |> should
      |> be_equal("ready")
      |> or_fail_with("service should become ready")
    }),
  ])
}
```

### 📣 Reporting: progress + results reporters

**Why this change:** parallel execution means completion order is not declaration order.
Dream Test splits reporting so live progress can react to completion order, while
final reports are printed in traversal order (deterministic).

The runner emits structured events (`reporters/types.ReporterEvent`):

- `RunStarted(total)`
- `TestFinished(completed, total, result)`
- `HookStarted(...)` / `HookFinished(...)`
- `RunFinished(completed, total, results)` (results are traversal-ordered)

Built-in reporters:

- `progress.new()` (live progress during the run)
- `bdd.new()` (human-readable BDD report printed at the end)
- `json.new()` (machine-readable JSON printed at the end)

Practical guidance:

- Use **progress + bdd** for readable local output.
- Use **json** for CI/tooling (optionally alongside progress).

### 🧯 Sandbox: optional crash reports (`dream_test/sandbox`)

**Why this change:** crash reports are useful when debugging locally, but they’re noisy in CI. 2.0 keeps crash isolation while letting you opt into crash logs when you need them.

Crashes are still isolated, but you can control whether the BEAM prints crash reports:

- `SandboxConfig(show_crash_reports: False)` suppresses noisy `=CRASH REPORT====` output (default).
- `sandbox.with_crash_reports(config)` enables crash reports for local debugging.

## Breaking changes & migration guide

If you’re upgrading from Dream Test 1.x → 2.0, do this in order. Most projects can upgrade in **10–20 minutes** by following these steps.

### Step 0: bump the dependency

```toml
[dev-dependencies]
dream_test = "~> 2.0"
```

Then:

```bash
gleam deps download
```

### Step 1: update imports (search/replace)

**Why this change:** the public surface was consolidated so users have one obvious place to import assertions (`dream_test/matchers`) and one obvious place to import reporters (`dream_test/reporters`).

- `dream_test/assertions/should` → `dream_test/matchers`
- `dream_test/reporter` → `dream_test/reporters`

### Step 2: replace your runner entrypoint with the v2 builder

**Why this change:** Dream Test is intentionally explicit about “what runs and how.” In 2.0, the builder pipeline is that single, inspectable place.

Most 1.x projects had a “run test cases then report” entrypoint. In 2.0, you **run suites directly**:

```gleam
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

### Step 3: update `it(...)` bodies to return `Result(_, String)`

This is the big ergonomic change in 2.0:

- **Most matcher chains already work as-is**: `... |> or_fail_with("...")` returns `Result(AssertionResult, String)`, so you can return it directly from the test.
- If you used `succeed()` / `fail_with(...)` in a branch, wrap it in `Ok(...)`.
- If setup should abort the test immediately, return `Error("human message")`.

Examples:

```gleam
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should, succeed}
import dream_test/unit.{it}
import gleam/result

// These are example `it(...)` bodies. In real code they live inside a `describe("...", [ ... ])` suite.
fn load_fixture() -> Result(String, String) {
  Error("fixture missing")
}

fn start_service(_fixture: String) -> Result(String, String) {
  Error("service failed to start")
}

// 1) Typical matcher chain (no wrapper needed): return `... |> or_fail_with(...)`
it("ready", fn() {
  "ready"
  |> should
  |> be_equal("ready")
  |> or_fail_with("expected status to be ready")
})

// 2) Branchy logic: wrap AssertionResult in Ok(...)
it("branch", fn() {
  Ok(case True {
    True -> succeed()
    False -> fail_with("expected flag to be True")
  })
})

// 3) Multi-step setup: use `result.try` (error must be String)
it("setup", fn() {
  use fixture <- result.try(load_fixture())
  use status <- result.try(start_service(fixture))
  status
  |> should
  |> be_equal("ready")
  |> or_fail_with("service should become ready")
})
```

### Step 4 (optional): migrate filtering to `runner.filter_tests`

**Why this change:** filtering now happens **before execution**, so skipped subtrees don’t run hooks and don’t waste time. The predicate is also intentionally small (`TestInfo`) so it’s easy to drive from env/CLI inputs.

If you previously filtered via `RunnerConfig.test_filter`, switch to pre-execution filtering:

```gleam
import dream_test/runner.{type TestInfo}
import gleam/list

pub fn only_smoke(info: TestInfo) -> Bool {
  list.contains(info.tags, "smoke")
}
```

Then:

```gleam
runner.new([tests()])
|> runner.filter_tests(only_smoke)
|> runner.run()
```

### Step 5 (optional but recommended): migrate to the discovery system (`dream_test/discover`)

**Why this change:** explicit suite lists are the most obvious, but some teams prefer “run everything matching *_test.” Discovery keeps `main()` explicit while removing the manual import list burden as suites grow.

If your 1.x setup relied on “test files being present” or you had a long manual import list, v2 discovery is the simplest upgrade path:

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

Notes:

- `from_path("unit/**_test.gleam")` is a **module path glob under `./test/`** (the `.gleam` extension is optional).
- Discovery loads modules that export `tests/0` and calls it to obtain `TestSuite(Nil)` values.

### Step 6 (if you use Gherkin): `world.get` now errors with a message

`dream_test/gherkin/world.get` now returns `Result(a, String)` so you can propagate a useful error:

```gleam
import dream_test/gherkin/world

case world.get(context.world, "count") {
  Ok(count) -> ...
  Error(message) -> Error(message)
}
```

## Documentation & guides

- `CHANGELOG.md` (2.0.0 section)
- `documentation/02-quick-start.md`
- `documentation/07-runner-and-execution.md`
- `documentation/08-reporters.md`
- `documentation/11-utilities.md` (sandbox)
