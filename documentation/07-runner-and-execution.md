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

#### Concurrency and timeouts <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/runner/runner_config.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Sequential execution (when shared resources matter)

When tests share external state, you often want `max_concurrency(1)` to avoid flakiness.

#### Sequential execution <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/runner/sequential_execution.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Suites with different contexts in one run

`runner.new`, `runner.add_suites` and `runner.add_suites_with_config` take a `List(TestSuite)`. A `TestSuite` (from `dream_test/suite`) has no type parameter, because each suite keeps its context inside it. So one run can hold a `unit` suite, a `unit_context` suite with any context type, and a Gherkin feature. See [Gherkin: a set-up for all scenarios](10-gherkin-bdd.md#a-set-up-for-all-scenarios-for-example-a-server) for an example.

To make a suite from a `types.Root` that you build yourself, use `suite.from_tree`.

To make one suite from several suites, use `suite.group` or `suite.join`. Each suite keeps its own context in both:

- `suite.group(name:, suites:)` puts each suite in a group named `name`. The group name is the first name of each test: `["Shop", "Cart", "starts empty"]`.
- `suite.join(name:, suites:)` adds no group. Each test keeps its own names: `["Cart", "starts empty"]`. The runner sees one suite named `name`, so `before_each_suite` runs one time for all of them.

`discover.to_suite` uses both: each module suite goes in the group, and the load errors stay directly under the suite name.

A discovery pattern that matches no test module is a load error (`<pattern>: no test module matches the pattern`), and so is a test module that does not load (`<module>: cannot load the module: <reason>`). Each load error is a failing test, so a wrong pattern never gives a run that passes with no tests.

#### Put suites in a group <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/runner/group_and_join.gleam#L24-L27"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Each suite becomes a group inside "Shop".
pub fn grouped() -> TestSuite {
  suite.group(name: "Shop", suites: [cart_suite(), stock_suite()])
}
```

#### Join suites in one suite <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/runner/group_and_join.gleam#L29-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// One suite named "Shop" that holds both suites as they are.
pub fn joined() -> TestSuite {
  suite.join(name: "Shop", suites: [cart_suite(), stock_suite()])
}
```

### Mixed execution policies (per-suite concurrency/timeout)

If only *some* suites share external state (for example: database suites) you don’t need two separate runners.
Instead, run everything in one runner and apply an execution config override to the suites that need it.

#### Execution config for each suite <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/runner/suite_specific_config.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{succeed}
import dream_test/parallel
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}

fn unit_tests() {
  describe("Unit suite", [
    it("is fast", fn() { Ok(succeed()) }),
  ])
}

fn db_tests() {
  describe("DB suite (sequential)", [
    it("pretend db test", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  configured_runner()
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

/// The unit suite runs with the run config. The DB suite runs one test at
/// a time, with a 60s timeout.
pub fn configured_runner() -> runner.RunBuilder {
  let db_config =
    parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 60_000)

  runner.new([])
  |> runner.add_suites([unit_tests()])
  |> runner.add_suites_with_config(db_config, [db_tests()])
  |> runner.max_concurrency(8)
  |> runner.default_timeout_ms(10_000)
}
```

### Runner hooks (test/suite/run)

Runner hooks let you apply setup/teardown **across suites** without modifying
each suite’s contents. Hooks are metadata-aware and receive structured info
about what is running.

**`types.TestInfo` fields**:

- `name`: leaf test name (`it("...")`)
- `groups`: the names of the groups around the test, outermost first (e.g. `["outer", "inner"]`). `types.full_name(info.groups, info.name)` gives the group path + test name (e.g. `["outer", "inner", "leaf"]`).
- `tags`: effective tags (includes inherited group tags)
- `kind`: `types.TestKind` (Unit, GherkinScenario(scenario_id:, rule:), etc.)
- `source`: best-effort origin string (see below)

**`types.SuiteInfo` fields**:

- `name`: top-level suite/group name
- `tests`: deterministic list of `TestInfo` values that will execute
- `source`: best-effort origin string (see below)

**Hook signatures**:

- `before_each_test` / `after_each_test` receive `types.TestInfo` and return `Result(Nil, String)`. They do not get the context of the test: the suites of one run can have different context types, and each suite keeps its own context.
- `before_each_suite` / `after_each_suite` receive `types.SuiteInfo`.
- `before_all_suites` / `after_all_suites` receive the full list of `SuiteInfo` after filtering.

**Failures and where the hooks run**:

- A failed `before_each_test`, `before_each_suite` or `before_all_suites` hook gives `SetupFailed` to the tests that it serves.
- A failed `after_each_test`, `after_each_suite` or `after_all_suites` hook does not change a test status. All the remaining tear-down hooks still run, the failure goes into `types.report_teardown_failures(report)`, and the run fails.
- The suite-level hooks run in one setup process for each scope, so a pool that `before_all_suites` starts lives until `after_all_suites` stops it. Each hook gets the default timeout. A hook that never returns fails with `hook timed out`, and the run goes on. The per-test hooks run in the process of the test (see [Where hooks run](06-lifecycle-hooks.md#where-hooks-run)).

`source` is best-effort:

- Unit discovery suites use the **module name**.
- Gherkin discovery suites use the **.feature path**.
- Manually constructed suites use `None`.

#### Runner hooks <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/runner/runner_hooks.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{succeed}
import dream_test/runner
import dream_test/types.{type SuiteInfo, type TestInfo}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/io
import gleam/list
import gleam/string

pub fn tests() {
  describe("Example", [
    it("a", fn() { Ok(succeed()) }),
    it("b", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.before_all_suites(before_all_suites_hook)
  |> runner.before_each_suite(before_each_suite_hook)
  |> runner.before_each_test(before_each_test_hook)
  |> runner.after_each_test(after_each_test_hook)
  |> runner.run()
}

fn before_all_suites_hook(suites: List(SuiteInfo)) -> Result(Nil, String) {
  io.println("suites: " <> int.to_string(list.length(suites)))
  Ok(Nil)
}

fn before_each_suite_hook(suite: SuiteInfo) -> Result(Nil, String) {
  io.println("suite: " <> suite.name)
  Ok(Nil)
}

fn before_each_test_hook(info: TestInfo) -> Result(Nil, String) {
  io.println(
    "test: " <> string.join(types.full_name(info.groups, info.name), " > "),
  )
  Ok(Nil)
}

fn after_each_test_hook(_info: TestInfo) -> Result(Nil, String) {
  Ok(Nil)
}
```

### Choosing a concurrency number (practical guidance)

- Start with the default.
- If you see flakes involving ports/files/DB state, either isolate those resources per test or set `max_concurrency(1)` for that run.
- If you have a large suite of pure unit tests (no external state), increasing concurrency often speeds up feedback noticeably.

### Advanced: running the executor directly

Most users should not call `dream_test/parallel` directly. It’s public so advanced tooling can embed the executor. The executor runs a typed tree, a `types.Root(context)`. Build one with `types.root`, not with `unit.describe`, which gives a `TestSuite`.

#### Run the executor directly <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/utils/parallel_direct.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{have_length, or_fail_with, should, succeed}
import dream_test/parallel
import dream_test/types
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Parallel executor", [
    it("can run a suite and return a report of the results", fn() {
      let suite =
        types.root("Suite", Nil, [
          it("a", fn() { Ok(succeed()) }),
          it("b", fn() { Ok(succeed()) }),
        ])

      parallel.run_root_parallel(parallel.default_config(), suite)
      |> types.report_tests
      |> should
      |> have_length(2)
      |> or_fail_with("expected two results")
    }),
  ])
}
```

### What's Next?

- Go back to [Lifecycle hooks](06-lifecycle-hooks.md)
- Go back to [Documentation README](README.md)
- Continue to [Reporters](08-reporters.md)
