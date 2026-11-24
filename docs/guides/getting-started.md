# Write and run your first test

You have a Gleam project and you want tests for it. Not a toy demo, but a setup you'll keep: a test file, a run that tells you what passed, a failure you can read at a glance, and a CI job that goes red when a test breaks. This guide takes you from an empty test folder to all of that, and shows you the real output at every step, both when things pass and when they don't.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [How Dream Test runs your tests](#how-dream-test-runs-your-tests)
- [Step 1: Write a test file](#step-1-write-a-test-file)
- [Step 2: Run it and read the report](#step-2-run-it-and-read-the-report)
- [Step 3: Break a test and read the failure](#step-3-break-a-test-and-read-the-failure)
- [Step 4: Make CI fail when a test fails](#step-4-make-ci-fail-when-a-test-fails)
- [Step 5: Find test files with discovery](#step-5-find-test-files-with-discovery)
- [When discovery finds nothing](#when-discovery-finds-nothing)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you'll:

- Write a test module with two tests and a `main` that runs them.
- Run it with `gleam test` and read the report.
- Break a test on purpose, and read what the failure tells you.
- Make the run end with exit status 1 when a test fails, so CI goes red.
- Let discovery find your test modules, so you don't keep a list by hand.
- See what happens when a discovery pattern finds nothing.

## Before you start

You need a Gleam project that targets Erlang. Dream Test runs on the BEAM only. Add Dream Test as a dev dependency, because tests are part of your build, not of your program:

```sh
gleam add --dev dream_test
```

The examples test two small functions of a module named `snippets`: `add(a, b)` returns the sum of two `Int`s, and `divide(a, b)` returns `Ok(a / b)`, or `Error("Cannot divide by zero")` when `b` is 0. Use any module of your own in their place.

Every example on this page is a file in the `examples/snippets` project of the Dream Test repository, and its tests run each one. In a clone of the repository, `make snippets` runs them all. The outputs on this page are the real outputs of that code, with every time set to 0, so the page stays the same from run to run. In your run, a test that takes 1 ms or more shows its time after its name, as in `(3ms)`, and the summary line ends with the time of the run.

## How Dream Test runs your tests

Dream Test doesn't scan your project for tests behind your back. `gleam test` runs the `main` function of one module, `test/<your project name>_test.gleam`, and that `main` builds a runner, gives it the suites to run, and starts it. So when a run surprises you, there's always a plain Gleam function you can read to find out why.

You have two ways to give the runner its suites:

| Your situation | Use | Why |
|:---|:---|:---|
| One or two test modules, or you want to see every suite in one place | A list of suites, `runner.new([cart.tests(), price.tests()])` | Nothing is hidden. The compiler tells you when a module is gone. |
| Many test modules, and you add new ones often | Discovery, `discover.tests("unit/**_test.gleam")` | A new module runs as soon as it exists. You don't keep an import list. |

Start with a list. [Step 5](#step-5-find-test-files-with-discovery) shows discovery.

## Step 1: Write a test file

`gleam new` makes a file `test/<your project name>_test.gleam`. Replace what's in it with this:

### A first test module <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/getting_started_first_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, be_ok, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}
import snippets.{add, divide}

pub fn tests() {
  describe("Calculator", [
    it("adds two numbers", fn() {
      add(2, 3)
      |> should
      |> be_equal(5)
      |> or_fail_with("2 + 3 should be 5")
    }),
    it("divides two numbers", fn() {
      divide(10, 2)
      |> should
      |> be_ok()
      |> be_equal(5)
      |> or_fail_with("10 / 2 should be 5")
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

Change `snippets` in the import to the module that holds your code. Here's what each part does:

- `describe("Calculator", [...])` names the thing you test and holds its tests. It returns a `TestSuite`, which is a plain value: `tests()` builds it, and `main` hands it to the runner.
- `it("adds two numbers", fn() { ... })` is one test. The name says what should be true, so the report reads like a list of facts about your code.
- The body is an assertion pipeline. It starts from the value you check, `should` starts the checks, `be_equal(5)` is a matcher, and `or_fail_with` gives the message you'll see if it fails. `be_ok()` checks that a `Result` is `Ok`, and hands the value inside to the next matcher. [Check values with matchers](https://github.com/TrustBound/dream_test/blob/main/docs/guides/assertions-and-matchers.md) covers every matcher.
- `main` is your policy: which suites run, what prints while they run (`progress_reporter`), what prints at the end (`results_reporters`), and how the program ends (`exit_on_failure`).

Always end an assertion with `or_fail_with`. Its message is the first thing you read when the test breaks, so write it for that moment.

## Step 2: Run it and read the report

Run the tests from your project folder:

### Run the tests <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/scripts/check.sh#L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sh
gleam test
```

You see this, and the exit status is 0:

### The first run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_getting_started_first_run.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
2/2 [███████████████████████████████████████████████████████████████] 100% done 
Calculator
  ✓ adds two numbers
  ✓ divides two numbers

Summary: 2 run, 0 failed, 2 passed in 0ms
```

The first line is the progress reporter. In a terminal it redraws one line as tests finish, and shows the name of the last test that finished. When the run ends, it shows `done`. Under it, the BDD reporter prints the whole run in the shape of your `describe` and `it` calls, with `✓` for each test that passed, then the summary line.

## Step 3: Break a test and read the failure

A test you've never seen fail is a test you can't trust yet. So add one that's wrong on purpose. Integer division in Gleam rounds toward zero, but this test expects `7 / 2` to round up:

### A test that fails <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/getting_started_failing_test.gleam#L29-L35"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    it("rounds a division up", fn() {
      divide(7, 2)
      |> should
      |> be_ok()
      |> be_equal(4)
      |> or_fail_with("7 / 2 should round up to 4")
    }),
```

Run `gleam test` again. This time the exit status is 1, and the report reads:

### The run with a failing test <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_getting_started_failing_run.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
3/3 [███████████████████████████████████████████████████████████████] 100% done 
Calculator
  ✓ adds two numbers
  ✓ divides two numbers
  ✗ rounds a division up
    be_equal
      Message: 7 / 2 should round up to 4
      Expected: 4
      Actual:   3

Failures:
Calculator
  ✗ rounds a division up
    be_equal
      Message: 7 / 2 should round up to 4
      Expected: 4
      Actual:   3

Summary: 3 run, 1 failed, 2 passed in 0ms
```

Read a failure from the top down:

- `✗ rounds a division up` is the test, under the groups around it.
- `be_equal` is the matcher that failed. `be_ok()` passed, because `divide(7, 2)` is `Ok(3)`, so the failure is about the value, not the `Result`.
- `Message` is your `or_fail_with` text. `Expected` and `Actual` are the two values.
- The `Failures:` section prints each failure again after the full report. In a run of a thousand tests, you scroll to the bottom and find every failure there.

The other tests still ran and passed. A failure in one test never stops the others. Here the test is wrong, not the code, so fix the test: expect `3`, or remove it.

## Step 4: Make CI fail when a test fails

CI decides whether a job passed by the exit status of `gleam test`. `runner.exit_on_failure()` in `main` is what makes it 1 when the run fails. Without it, the exit status is 0 even when tests fail, and your CI job stays green.

`exit_on_failure` doesn't stop at the first failure. Every test runs, every reporter prints, and coverage files get written. Then the program ends with exit status 1. When the run passes, `runner.run` returns the run report and the exit status is 0.

The run fails, and the exit status is 1, in any of these cases:

- a test is `Failed`, `TimedOut` or `SetupFailed`
- a teardown hook failed
- the process that keeps a setup alive stopped while its tests ran
- a custom results reporter crashed
- coverage failed, for example a total below the minimum

[Run a large suite fast and predictably](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md#step-6-decide-the-exit-status) shows each case, and how to pick your own exit status from the report.

## Step 5: Find test files with discovery

Once you have more than a handful of test modules, the import list in `main` becomes a chore, and a module you forget to add never runs. Discovery finds the modules for you:

### A runner that discovers test modules <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/getting_started_discovery.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/discover
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner

pub fn main() {
  runner.new(suites())
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

/// The suites of every test module under `test/snippets/guides/` whose
/// name ends in `_check`.
pub fn suites() {
  discover.tests("snippets/guides/**_check.gleam")
  |> discover.to_suites()
}
```

How discovery works:

- The pattern names files under `test/`. In your project, use your own folder, for example `unit/**_test.gleam` for `test/unit/cart_test.gleam`. `**` matches any number of folders.
- Each module it finds must have `pub fn tests()` that returns a `TestSuite`. Discovery skips a module without it, and gives no error for it, so helper modules can live next to your tests.
- `tests()` can return any suite: a `unit` suite, a `unit_context` suite with its own context, or a Gherkin feature.
- `to_suites()` gives one suite for each module it loaded, plus a failing test for each module it could not load (see [When discovery finds nothing](#when-discovery-finds-nothing)).

`discover.new() |> discover.from_path(pattern)` builds the same discovery. Call `from_path` more than once to add more patterns.

## When discovery finds nothing

Move a test folder, mistype the pattern, and discovery finds no module. A run that passes with zero tests would hide that, so Dream Test turns it into a failing test. Here's the run of the same runner with the pattern `snippets/units/**.gleam`, a folder that doesn't exist. The exit status is 1:

### A pattern that matches no module <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_getting_started_wrong_pattern.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
1/1 [███████████████████████████████████████████████████████████████] 100% done 
Discovery Errors
  ✗ Discovery Error: snippets/units/**.gleam: no test module matches the pattern
    discover
      Message: Failed to discover/load test modules (see test name for details)

Failures:
Discovery Errors
  ✗ Discovery Error: snippets/units/**.gleam: no test module matches the pattern
    discover
      Message: Failed to discover/load test modules (see test name for details)

Summary: 1 run, 1 failed, 0 passed in 0ms
```

The test name holds the problem. Discovery has five of them, and each one is a failing test in the `Discovery Errors` group:

| The test name says | It means |
|:---|:---|
| `<pattern>: no test module matches the pattern` | No module under `test/` matches, or none that matches has `tests()`. |
| `<pattern>: cannot search for test modules: <class>:<reason>` | The pattern itself is broken. |
| `<module>: cannot load the module: <reason>` | The compiled module doesn't load. |
| `<module>: tests() crashed: <class>:<reason>` | Your `tests()` function crashed while it built the suite. |
| `<module>: tests() did not return a test suite: <value>` | `tests()` returned something else. |

A run that finds its modules but runs no test fails too, for example a filter with a typo in a tag. That run has no failing test: the report ends with the line `No tests ran. The filter or the suites selected no test. To allow an empty run, use runner.allow_no_tests().` and the exit status is 1. [When a filter keeps nothing](https://github.com/TrustBound/dream_test/blob/main/docs/guides/writing-tests.md#when-a-filter-keeps-nothing) shows that run, and `runner.allow_no_tests()` for a run that is empty on purpose.

## Test your code

Your tests are code too, and the check that matters most is that a broken test really breaks the run. You can test that with Dream Test itself: build the suite, run it with `runner.silent()` so it prints nothing, and check the report that `runner.run` returns. This module checks the failing suite from Step 3:

### Check that a failing test fails the run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/getting_started_runner_check.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, be_true, or_fail_with, should}
import dream_test/runner
import dream_test/types.{type RunReport, type TestResult}
import dream_test/unit.{describe, it}
import gleam/list
import snippets/guides/getting_started_failing_test.{failing_tests}

pub fn tests() {
  describe("The calculator tests", [
    it("fail the run when a test fails", fn() {
      // Act
      let report =
        runner.new([failing_tests()])
        |> runner.silent()
        |> runner.run()

      // Assert
      types.failed(report)
      |> should
      |> be_true()
      |> or_fail_with("a failing test should fail the run")
    }),
    it("report the failing test by its name", fn() {
      // Act
      let report =
        runner.new([failing_tests()])
        |> runner.silent()
        |> runner.run()

      // Assert
      failed_test_names(report)
      |> should
      |> be_equal(["rounds a division up"])
      |> or_fail_with("only the rounding test should fail")
    }),
  ])
}

fn failed_test_names(report: RunReport) -> List(String) {
  types.report_tests(report)
  |> list.filter(is_failed)
  |> list.map(test_name)
}

fn is_failed(result: TestResult) -> Bool {
  types.is_failure(result.status)
}

fn test_name(result: TestResult) -> String {
  result.name
}
```

`types.failed(report)` is `True` when the run fails, and `types.report_tests(report)` gives one `TestResult` for each test, with its name, its status and its failures. The failing suite lives in its own function, `failing_tests()`, not in `tests()`, so discovery doesn't run it as one of your tests. The discovery runner from Step 5 finds this module, because its name ends in `_check`, and prints:

### The run of the check <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_getting_started_discovery.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
2/2 [███████████████████████████████████████████████████████████████] 100% done 
The calculator tests
  ✓ fail the run when a test fails
  ✓ report the failing test by its name

Summary: 2 run, 0 failed, 2 passed in 0ms
```

## Common pitfalls

**No `exit_on_failure` in `main`.** *Symptom:* the report shows failures, but the CI job is green. *Fix:* add `runner.exit_on_failure()` before `runner.run()`. Without it, the exit status is always 0.

**The runner module has the wrong name.** *Symptom:* `gleam test` runs something else, or nothing of yours. *Fix:* `gleam test` runs `main` of `test/<name>_test.gleam` only, where `<name>` is the `name` in your `gleam.toml`. Put your `main` there.

**A test module that discovery skips.** *Symptom:* a module's tests never show in the report, and no error says why. *Fix:* the module needs `pub fn tests()`. A module without it is skipped on purpose, so a typo in the function name hides the whole module.

**A discovery pattern relative to the wrong folder.** *Symptom:* `no test module matches the pattern`. *Fix:* the pattern starts under `test/`, so write `unit/**_test.gleam`, not `test/unit/**_test.gleam`.

**An assertion without `or_fail_with`.** *Symptom:* a test body doesn't compile, because it returns a `MatchResult` and not an assertion result. *Fix:* end every pipeline with `or_fail_with("...")`.

## Where to go next

- [Organize tests with groups, skips and tags](https://github.com/TrustBound/dream_test/blob/main/docs/guides/writing-tests.md): shape a growing suite so its report stays readable.
- [Check values with matchers](https://github.com/TrustBound/dream_test/blob/main/docs/guides/assertions-and-matchers.md): every matcher, and the failure each one prints.
- [Set up and tear down around tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/lifecycle-hooks.md): hooks for code that needs a database, a server or a temp folder.
- [Choose and read the test output](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reporters.md): reporters for the terminal and for CI.
- [Run a large suite fast and predictably](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md): parallelism, timeouts, filters and the exit status.
- [API reference on HexDocs](https://hexdocs.pm/dream_test/): `runner`, `unit`, `discover` and the rest.
