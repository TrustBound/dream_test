## Runner & execution model

### Mental model

- You control **how fast** tests run with `max_concurrency`.
- You control **how long** tests may run with `default_timeout_ms`.
- You control **CI behavior** with `exit_on_failure`.

Dream Test is **suite-first**:

- You define suites with `dream_test/unit` or `dream_test/unit_context`
- You run them with `dream_test/runner`

<sub>(Under the hood: the runner uses the parallel executor, but most users never need to call it directly.)</sub>

### Configure parallelism + timeouts

Use `max_concurrency` and `default_timeout_ms` to tune execution:

- **Higher concurrency** speeds up independent tests.
- **Lower concurrency** is safer for tests that share external resources (DBs, ports, filesystem paths).

```gleam
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporter
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() {
  describe("Runner config demo", [
    it("runs with custom config", fn() {
      1 + 1
      |> should()
      |> equal(2)
      |> or_fail_with("Math works")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.max_concurrency(8)
  |> runner.default_timeout_ms(10_000)
  |> runner.reporter(reporter.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/runner/runner_config.gleam)</sub>

### Sequential execution (when shared resources matter)

When tests share external state, you often want `max_concurrency(1)` to avoid flakiness.

```gleam
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporter
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() {
  describe("Sequential tests", [
    it("first test", fn() {
      // When tests share external resources, run them sequentially
      1 + 1
      |> should()
      |> equal(2)
      |> or_fail_with("Math works")
    }),
    it("second test", fn() {
      2 + 2
      |> should()
      |> equal(4)
      |> or_fail_with("Math still works")
    }),
  ])
}

pub fn main() {
  // Sequential execution for tests with shared state
  runner.new([tests()])
  |> runner.max_concurrency(1)
  |> runner.default_timeout_ms(30_000)
  |> runner.reporter(reporter.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/runner/sequential_execution.gleam)</sub>

### Advanced: running the executor directly

Most users should not call `dream_test/parallel` directly. It’s public so advanced tooling can embed the executor.

```gleam
import dream_test/assertions/should.{have_length, or_fail_with, should, succeed}
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
      |> should()
      |> have_length(2)
      |> or_fail_with("expected two results")
    }),
  ])
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/utils/parallel_direct.gleam)</sub>


