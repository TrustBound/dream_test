## Runner & execution model

This chapter is about turning “a suite” into “a reliable test run.”

Suites describe behavior; the runner decides execution policy. The runner exists so you can make those policies explicit instead of relying on defaults you can’t see.

### Mental model

- You control **how fast** tests run with `max_concurrency`.
- You control **how long** tests may run with `default_timeout_ms`.
- You control **CI behavior** with `exit_on_failure`.

Dream Test is **suite-first**:

- You define suites with `dream_test/unit` or `dream_test/unit_context`
- You run them with `dream_test/runner`

<sub>(Under the hood: the runner uses the parallel executor, but most users never need to call it directly.)</sub>

### Why Dream Test is explicit here

Most testing pain shows up at the runner layer:

- Flakiness due to shared resources + parallelism
- Hung tests that stall CI
- Output that is hard to interpret under concurrency

Dream Test’s runner makes those constraints visible and configurable.

### Configure parallelism + timeouts

Use `max_concurrency` and `default_timeout_ms` to tune execution:

- **Higher concurrency** speeds up independent tests.
- **Lower concurrency** is safer for tests that share external resources (DBs, ports, filesystem paths).

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Runner config demo", [
    it("runs with custom config", fn() {
      1 + 1
      |> should
      |> be_equal(2)
      |> or_fail_with("Math works")
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

<sub>🧪 [Tested source](../examples/snippets/test/snippets/runner/runner_config.gleam)</sub>

### Sequential execution (when shared resources matter)

When tests share external state, you often want `max_concurrency(1)` to avoid flakiness.

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Sequential tests", [
    it("first test", fn() {
      // When tests share external resources, run them sequentially
      1 + 1
      |> should
      |> be_equal(2)
      |> or_fail_with("Math works")
    }),
    it("second test", fn() {
      2 + 2
      |> should
      |> be_equal(4)
      |> or_fail_with("Math still works")
    }),
  ])
}

pub fn main() {
  // Sequential execution for tests with shared state
  runner.new([tests()])
  |> runner.max_concurrency(1)
  |> runner.default_timeout_ms(30_000)
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/runner/sequential_execution.gleam)</sub>

### Mixed execution policies (per-suite concurrency/timeout)

If only *some* suites share external state (for example: database suites) you don’t need two separate runners.
Instead, run everything in one runner and apply an execution config override to the suites that need it.

```gleam
import dream_test/parallel
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner

pub fn main() {
  let db_config =
    parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 60_000)

  runner.new([])
  |> runner.add_suites([unit_tests()])
  |> runner.add_suites_with_config(db_config, [db_tests()])
  |> runner.max_concurrency(8)
  |> runner.default_timeout_ms(10_000)
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/runner/suite_specific_config.gleam)</sub>

### Choosing a concurrency number (practical guidance)

- Start with the default.
- If you see flakes involving ports/files/DB state, either isolate those resources per test or set `max_concurrency(1)` for that run.
- If you have a large suite of pure unit tests (no external state), increasing concurrency often speeds up feedback noticeably.

### Advanced: running the executor directly

Most users should not call `dream_test/parallel` directly. It’s public so advanced tooling can embed the executor.

```gleam
import dream_test/matchers.{have_length, or_fail_with, should, succeed}
import dream_test/parallel
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Parallel executor", [
    it("can run a suite and return a list of results", fn() {
      let suite =
        describe("Suite", [
          it("a", fn() { Ok(succeed()) }),
          it("b", fn() { Ok(succeed()) }),
        ])

      parallel.run_root_parallel(parallel.default_config(), suite)
      |> should
      |> have_length(2)
      |> or_fail_with("expected two results")
    }),
  ])
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/utils/parallel_direct.gleam)</sub>

### What's Next?

- Go back to [Lifecycle hooks](06-lifecycle-hooks.md)
- Go back to [Documentation README](README.md)
- Continue to [Reporters](08-reporters.md)
