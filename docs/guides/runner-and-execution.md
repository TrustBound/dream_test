# Run a large suite fast and predictably

A suite of thirty tests runs in a blink however you set it up. A suite of three thousand, with database tests, a few slow calls and one test that sometimes hangs, needs decisions: how many tests run at once, how long a test may take, which suites must run alone, and what exactly makes CI go red. Dream Test makes each of those a line in your `main`, so the policy is in one place you can read. This guide walks through them, with the real output of a test that hangs and a CI runner that uses them all.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [How the runner schedules tests](#how-the-runner-schedules-tests)
- [Which setting for which problem](#which-setting-for-which-problem)
- [Step 1: Set the concurrency and the timeout](#step-1-set-the-concurrency-and-the-timeout)
- [Step 2: See a test time out](#step-2-see-a-test-time-out)
- [Step 3: Run the suites that share a resource one test at a time](#step-3-run-the-suites-that-share-a-resource-one-test-at-a-time)
- [Step 4: Combine suites](#step-4-combine-suites)
- [Step 5: Run part of the suite](#step-5-run-part-of-the-suite)
- [Step 6: Decide the exit status](#step-6-decide-the-exit-status)
- [Run one test](#run-one-test)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you'll:

- Tune how many tests run at once, and how long each may take.
- Read the report of a test that hangs past its timeout.
- Run database suites one test at a time, next to unit suites that run in parallel.
- Combine explicit suites, discovered suites and a suite with its own settings in one CI runner.
- Know every case that makes the exit status 1, and check your policy with a test.

## Before you start

You need Dream Test as a dev dependency and a test runner module. [Write and run your first test](https://github.com/TrustBound/dream_test/blob/main/docs/guides/getting-started.md) sets both up.

```sh
gleam add --dev dream_test
```

The outputs on this page are real outputs of the code shown, with every time set to 0, so they stay the same from run to run.

## How the runner schedules tests

The runner runs each test in its own process, so a test that crashes or hangs can't take the others down with it. Within that:

- The suites run one after the other.
- Inside a suite, the groups run one after the other: first the direct tests of a group, then each child group, in the written order.
- Only the direct tests of one group run at the same time, up to `max_concurrency` of them.

So parallelism comes from groups with many tests, and the order of groups and suites stays fixed. The default is `max_concurrency` 4 and `default_timeout_ms` 5000 (`parallel.default_config()`).

## Which setting for which problem

| Your situation | Use | Why |
|:---|:---|:---|
| Many independent, pure tests, and the run is slow | `runner.max_concurrency(8)` or more | More tests of a group run at once. |
| Tests share a port, a folder or a database schema, and fail at random | `runner.add_suites_with_config` with `max_concurrency: 1` for those suites | They run one at a time, the rest stay parallel. |
| A test or a hook hangs and stalls CI | `runner.default_timeout_ms(ms)` | The runner stops waiting, marks it, and goes on. |
| Slow but healthy tests time out on a slow CI machine | A higher timeout for the suites that need it | Keep a tight default for the rest. |
| Only some tests should run | `runner.filter_tests(predicate)` | Filters by name, groups, tags or kind. |
| CI must go red on any problem | `runner.exit_on_failure()` | Exit status 1 when the run fails. |

## Step 1: Set the concurrency and the timeout

Here's a runner for CI with all the settings of this guide in one place:

### A CI runner <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/runner_ci_runner.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/discover
import dream_test/matchers.{succeed}
import dream_test/parallel
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/unit.{describe, it}
import snippets/guides/writing_tests_cart

pub fn main() {
  runner.new([writing_tests_cart.tests()])
  |> runner.add_suites(check_suites())
  |> runner.add_suites_with_config(database_config(), [database_tests()])
  |> runner.max_concurrency(8)
  |> runner.default_timeout_ms(10_000)
  |> runner.results_reporters([bdd.new() |> bdd.summary_only()])
  |> runner.exit_on_failure()
  |> runner.run()
}

fn check_suites() {
  discover.tests("snippets/guides/**_check.gleam")
  |> discover.to_suites()
}

/// The database tests share one schema, so they run one at a time, and a
/// slow query gets a minute.
fn database_config() -> parallel.ParallelConfig {
  parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 60_000)
}

fn database_tests() {
  describe("Database", [
    it("creates a user", fn() { Ok(succeed()) }),
    it("deletes a user", fn() { Ok(succeed()) }),
  ])
}
```

`max_concurrency(8)` lets up to eight tests of a group run at once. A value below 1 counts as 1. `default_timeout_ms(10_000)` gives each test body ten seconds, and each hook ten seconds too.

The timeout must be at least 1. With 0, the tests and hooks that use it get no time, so they almost always time out, and the result isn't dependable. A value below 0 almost always stops the run with the Erlang error `timeout_value`, when the run waits for a hook in a setup process, such as a `before_all` hook.

The test timeout is the `timeout_ms` of the test when it has one, else the default timeout. `unit.it` and `unit_context.it` give no `timeout_ms`. Only a test you build with `types.Test(..., timeout_ms: Some(ms), ...)` has its own.

The run prints:

### The summary of the CI run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_runner_ci.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Summary: 9 run, 0 failed, 6 passed, 1 skipped, 2 pending in 0ms
```

## Step 2: See a test time out

A test that waits for a server that never answers would stall the run forever. The timeout stops that. Here's a suite with a test that sleeps for a second, run with a timeout of 200 ms:

### A test slower than the timeout <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/runner_timeout.gleam#L10-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn search_tests() {
  describe("Search", [
    it("answers fast", fn() { Ok(succeed()) }),
    it("waits for an index that never comes", fn() {
      process.sleep(1000)
      Ok(succeed())
    }),
  ])
}

pub fn run_with_a_short_timeout() -> RunReport {
  runner.new([search_tests()])
  |> runner.default_timeout_ms(200)
  |> runner.silent()
  |> runner.run()
}
```

### The report of a timed-out test <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_runner_timeout.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Search
  ✓ answers fast
  ! waits for an index that never comes
    timeout
      Message: test timed out
    Run it alone: gleam test -- --only "Search/waits for an index that never comes"

Failures:
Search
  ! waits for an index that never comes
    timeout
      Message: test timed out
    Run it alone: gleam test -- --only "Search/waits for an index that never comes"

Summary: 2 run, 0 failed, 1 passed, 1 timed out in 0ms
```

`!` marks a test that timed out. Its status is `TimedOut`, with the failure `timeout: test timed out`, and the summary counts it apart from the failed tests. The runner kills the test's process, runs the `after_each` hooks that didn't run yet in a new process, and goes on with the next test. The run fails.

A hook that hangs gets the same treatment: a setup hook gives `SetupFailed` with `hook timed out in <groups>`, and a teardown hook gives a teardown failure. [Set up and tear down around tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/lifecycle-hooks.md#when-a-hook-hangs) shows that report.

## Step 3: Run the suites that share a resource one test at a time

Most flaky suites share something: a port, a path, a database schema. Two tests that write the same row at the same time give a different result each run. You have two fixes:

- Give each test its own resource: a unique port from `process.unique_port()`, a temp folder named after the test, a schema for each test.
- Run the suites that share the resource one test at a time.

The CI runner above does the second for the database suite. `runner.add_suites_with_config(config, suites)` adds suites with their own `parallel.ParallelConfig`: here `max_concurrency: 1` and a timeout of a minute. The other suites keep the run's settings. One runner, two policies, and no second `gleam test`.

`runner.max_concurrency(1)` on the whole runner also works, but it makes every test wait for every other.

## Step 4: Combine suites

`runner.new`, `runner.add_suites` and `runner.add_suites_with_config` all take a `List(TestSuite)`. A `TestSuite` from `dream_test/suite` has no type parameter, because each suite keeps its context inside it. So one run holds `unit` suites, `unit_context` suites with any context type, Gherkin features, and the suites that discovery finds, as the CI runner does.

To make one suite from several, use `suite.group` or `suite.join`. Each suite keeps its own context in both:

### Put suites in a group <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/runner/group_and_join.gleam#L25-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Each suite becomes a group inside "Shop".
pub fn grouped() -> TestSuite {
  suite.group(name: "Shop", suites: [cart_suite(), stock_suite()])
}
```

`suite.group(name:, suites:)` puts each suite in a group named `name`. The group name becomes the first name of each test: `["Shop", "Cart", "starts empty"]`.

### Join suites in one suite <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/runner/group_and_join.gleam#L30-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// One suite named "Shop" that holds both suites as they are.
pub fn joined() -> TestSuite {
  suite.join(name: "Shop", suites: [cart_suite(), stock_suite()])
}
```

`suite.join(name:, suites:)` adds no group. Each test keeps its own names: `["Cart", "starts empty"]`. The runner sees one suite named `name`, so `before_each_suite` runs one time for all of them.

`discover.to_suite` uses both: each module suite goes in the group, and the load errors stay directly under the suite name. To make a suite from a `types.Tree` you build yourself, use `suite.from_tree`.

## Step 5: Run part of the suite

`runner.filter_tests(predicate)` runs only the tests for which the predicate returns `True`. It gets each test's `TestInfo`: name, groups, tags, kind and source. A group with no selected test doesn't run, and neither do its hooks. [Organize tests with groups, skips and tags](https://github.com/TrustBound/dream_test/blob/main/docs/guides/writing-tests.md#step-5-run-only-some-tests) shows filters by tag, and how to test them.

## Step 6: Decide the exit status

CI reads the exit status of `gleam test`. Without `runner.exit_on_failure()`, it's 0 even when the run fails: `runner.run` returns the report, `main` returns, and the CI step passes.

The run fails when one of these is true:

1. A test is `Failed`, `TimedOut` or `SetupFailed`.
2. A teardown hook failed, also when every test passed.
3. The process of a setup stopped while its tests ran (`types.SetupStopped`).
4. The `render` function of a `reporter_types.Custom` results reporter crashed.
5. The run ran no test, for example a filter that keeps nothing, and `runner.allow_no_tests()` is not set. A skipped or pending test is a test that ran.
6. Coverage failed, for example a total below `coverage.minimum_percent`.

`exit_on_failure` doesn't stop the run at the first failure. Every test runs, and the runner writes all its output, the reports and the coverage files. Then it ends the program with exit status 1, and `runner.run` doesn't return, so no code after it runs. When the run passes, `runner.run` returns the report, and the exit status is 0.

`types.failed(report)` is `True` in the first five cases, and `types.failed_with_no_tests(report)` in the fifth. `types.report_tests(report)` gives the test results, `types.report_hook_failures(report)` the failed teardowns and stopped setups, and `types.report_reporter_crashes(report)` the position and the full reason of each crashed results reporter. Use them when your code picks its own exit status from the report.

A silent run, `runner.silent()`, writes nothing to the standard output: no progress, no reports and no coverage table. It still writes three kinds of error to the standard error stream: the error of a `--only` path that selects no test, the `Results reporter failed` error of a custom reporter that crashed, and a coverage error.

## Run one test

Each failed test in the BDD and Gherkin reports ends with a `Run it alone:` line. The line holds the command that runs only that test. Copy the command, fix the code, and run the command until the test passes:

### Run one test of the recording guide <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/recording/scripts/playback.sh#L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sh
gleam test -- --only "Forecast/gives the forecast for Oslo"
```

The runner reads `--only` from the command line itself, so your `main` does not change. The rules:

1. The path is the suite name, the group names and the test name, joined with `/`. For a Gherkin scenario, it is the Feature name and the scenario name, as the report shows them, without `Feature:` and `Scenario:`.
2. The path must match the names exactly. The path of a group or a suite runs all the tests inside it.
3. Give `--only` more than one time to run the tests of each path.
4. In a name, write a `/` as `\/` and a `\` as `\\`. The printed commands do this for you.
5. `--only` works together with `runner.filter_tests`: a test runs only when the path selects it and the filter keeps it.
6. The hooks around the selected tests run as usual. The `before_all` of the suite runs one time, and so does each `before_all` of a group around a selected test.

A path that selects no test fails the run before any test or hook runs, also without `exit_on_failure`. The error lists the three closest paths as commands, and the exit status is 1. This is the error of a typo in the recording guide:

### The error of a path that selects no test <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/test/fixtures/only_unknown_path.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
No test has the --only path "Forecast/gives the forecast for Olso"
  Closest paths:
    gleam test -- --only "Forecast/gives the forecast for Oslo"
    gleam test -- --only "Forecast/gives the forecast for Lisbon"
    gleam test -- --only "Tasks/gives the share token of a task"
  Fix: use the full path: the suite name, the group names and the test name, joined with /. Write a / in a name as \/.
```

The printed command is safe to paste in a POSIX shell. A path with `"`, `$`, `` ` ``, `\` or `!` goes in single quotes, and a `'` in it becomes `'\''`. Only the outermost run reads the command line: a run that a test starts inside another run does not use `--only`.

## Test your code

The second case surprises people: a run where every test passed can still fail. That's on purpose, because a cleanup that didn't happen leaves a mess for the next run. The fifth case is on purpose too: a run that tested nothing proves nothing. If your CI depends on that policy, pin it with a test. Run a suite with a failing teardown silently, and check `types.failed`. Then run it with a filter that keeps nothing:

### Check that a failed cleanup fails the run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/runner_failure_policy.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_true, or_fail_with, should, succeed}
import dream_test/runner
import dream_test/types
import dream_test/unit.{after_all, describe, it}

/// Every test passes, but the cleanup fails.
fn suite_with_a_failed_cleanup() {
  describe("Uploads", [
    after_all(fn() { Error("could not delete the upload folder") }),
    it("stores a file", fn() { Ok(succeed()) }),
  ])
}

pub fn tests() {
  describe("The run report", [
    it("fails a run whose cleanup failed", fn() {
      // Act
      let report =
        runner.new([suite_with_a_failed_cleanup()])
        |> runner.silent()
        |> runner.run()

      // Assert
      types.failed(report)
      |> should
      |> be_true()
      |> or_fail_with("a failed teardown should fail the run")
    }),
    it("fails a run that ran no test", fn() {
      // Act
      let report =
        runner.new([suite_with_a_failed_cleanup()])
        |> runner.filter_tests(fn(_info) { False })
        |> runner.silent()
        |> runner.run()

      // Assert
      types.failed(report)
      |> should
      |> be_true()
      |> or_fail_with("a run with no test should fail")
    }),
  ])
}
```

### The report of the policy check <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_runner_check.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
The run report
  ✓ fails a run whose cleanup failed
  ✓ fails a run that ran no test

Summary: 2 run, 0 failed, 2 passed in 0ms
```

## Common pitfalls

**Tests that share a resource and run in parallel.** *Symptom:* a test fails once in ten runs, never alone. *Fix:* give each test its own resource, or run that suite with `max_concurrency: 1` through `add_suites_with_config`.

**A timeout of 0.** *Symptom:* every test times out, or the run stops with `timeout_value`. *Fix:* the timeout must be at least 1 ms. Use a few seconds.

**One slow suite sets the timeout for all.** *Symptom:* a hung unit test takes a minute to fail. *Fix:* keep the default tight, and give the slow suite its own timeout with `add_suites_with_config`.

**No `exit_on_failure`.** *Symptom:* failures in the log, green CI. *Fix:* add `runner.exit_on_failure()` before `runner.run()`.

**Code after `runner.run()`.** *Symptom:* a step after the run never happens when tests fail. *Fix:* with `exit_on_failure`, the program ends inside `runner.run`. Put the step in a custom results reporter, or a runner hook.

## Where to go next

- [Set up and tear down around tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/lifecycle-hooks.md): hooks, their processes and their timeouts.
- [Choose and read the test output](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reporters.md): reporters for CI, and custom ones.
- [Measure line coverage and gate CI on it](https://github.com/TrustBound/dream_test/blob/main/docs/guides/coverage.md): the fifth way a run fails.
- [Reference](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reference.md#run-the-executor-directly): the `parallel` executor, for tools of your own.
- [API reference on HexDocs](https://hexdocs.pm/dream_test/dream_test/runner.html): every runner setting.
