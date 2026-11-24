# Set up and tear down around tests

Some code can't be tested from a pure function call. It reads a file, talks to a database, or needs a server to be up. Each test needs that world in place before it starts, and the world has to be cleaned up after, even when the test fails. Hooks do that work. This guide shows each hook, the order they run in, what the report says when one of them fails or hangs, and how to set up something once for a whole run.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which hook to use](#which-hook-to-use)
- [Step 1: Make a fixture before the tests and remove it after](#step-1-make-a-fixture-before-the-tests-and-remove-it-after)
- [Step 2: See the order the hooks run in](#step-2-see-the-order-the-hooks-run-in)
- [Step 3: Set up once for a whole run](#step-3-set-up-once-for-a-whole-run)
- [When a setup hook fails](#when-a-setup-hook-fails)
- [When a teardown hook fails](#when-a-teardown-hook-fails)
- [When a hook hangs](#when-a-hook-hangs)
- [Which process runs each hook](#which-process-runs-each-hook)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you'll:

- Write a fixture file before a group of tests, and remove it after the last one.
- Print the order of every hook around a test in nested groups.
- Start a resource once for a whole run with runner hooks, and run code for each suite and each test.
- Read the report of a setup hook that fails, a teardown hook that fails, and a setup hook that hangs.
- Test that your cleanup hook really cleans up.

## Before you start

You need Dream Test as a dev dependency and a test runner module. [Write and run your first test](https://github.com/TrustBound/dream_test/blob/main/docs/guides/getting-started.md) sets both up, and [Organize tests with groups, skips and tags](https://github.com/TrustBound/dream_test/blob/main/docs/guides/writing-tests.md) shows how `describe` and `group` nest.

```sh
gleam add --dev dream_test
```

The outputs on this page are real outputs of the code shown, with every time set to 0, so they stay the same from run to run.

## Which hook to use

Hooks go in the list of a `describe` or a `group`, next to the tests. Each one is a function that returns `Ok(Nil)`, or `Error(message)` to fail.

| Your situation | Use | Why |
|:---|:---|:---|
| Fresh state for every test, such as an empty table | `before_each` and `after_each` | They run around each test of the group. `after_each` runs even when the test fails. |
| One expensive resource for all tests of a group, such as a fixture file | `before_all` and `after_all` | They run once for the group, before its first test and after its last. |
| The tests need the value that the setup made, such as a connection | `unit_context.describe` with `context.setup` | The setup returns a value, and every test gets it. See [Share a context between tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/context-aware-tests.md). |
| The same setup for every suite of a run, such as a database server | `runner.before_all_suites`, `runner.before_each_suite`, `runner.before_each_test` and their `after_` partners | Runner hooks wrap suites without changing them. |
| A few lines that the test reads to make sense | No hook. A named helper in the test body | A hook hides setup that explains the assertion. |

A good rule of thumb: when the setup is infrastructure (start a server, make a temp folder), a hook makes the test clearer. When the setup is what the test is about, keep it in the test.

## Step 1: Make a fixture before the tests and remove it after

These tests read a user from a file. `before_all` writes the file once, before the first test of the group. `after_all` deletes it after the last test:

### Write a fixture file before the tests <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/hooks_user_files.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/file
import dream_test/matchers.{be_equal, be_ok, or_fail_with, should}
import dream_test/unit.{after_all, before_all, describe, it}
import gleam/result
import gleam/string

/// The file that the hooks make and remove.
pub const alice_file = "build/guide_hooks/alice.txt"

pub fn tests() {
  describe("User files", [
    before_all(write_alice),
    after_all(delete_alice),
    it("reads a user", fn() {
      file.read(alice_file)
      |> should
      |> be_ok()
      |> be_equal("Alice")
      |> or_fail_with("the file should hold Alice")
    }),
    it("reads the name in capitals", fn() {
      file.read(alice_file)
      |> result.map(string.uppercase)
      |> should
      |> be_ok()
      |> be_equal("ALICE")
      |> or_fail_with("the name should be ALICE in capitals")
    }),
  ])
}

fn write_alice() -> Result(Nil, String) {
  file.write(alice_file, "Alice")
  |> result.map_error(file.error_to_string)
}

fn delete_alice() -> Result(Nil, String) {
  file.delete(alice_file)
  |> result.map_error(file.error_to_string)
}
```

A plain `unit` hook gets no arguments and returns `Result(Nil, String)`, so it can't hand a value to the tests. Here the tests find the file by its path, a constant that the hooks and the tests share. When the tests need a value that only the setup can make, such as a connection or a process, use a context instead ([Share a context between tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/context-aware-tests.md)).

The four hooks:

- `before_all` runs once before the first test of its group.
- `before_each` runs before each test of its group.
- `after_each` runs after each test of its group, also when the test fails.
- `after_all` runs once after the last test of its group.

A hook applies to its whole group, wherever it stands in the list. A `before_each` after a test still runs before that test. To give a hook to some tests only, put them in a nested `group`.

A hook runs only when at least one of the tests it serves runs. A group with no test, or one whose tests a filter left out, runs no `before_all` and no `after_all`.

## Step 2: See the order the hooks run in

When groups nest, their hooks stack. This suite prints a line from each hook:

### Print the order of the hooks <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/hooks_order.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/unit.{
  after_all, after_each, before_all, before_each, describe, group, it,
}
import gleam/io

pub fn tests() {
  describe("Outer", [
    before_all(fn() {
      io.println("outer before_all")
      Ok(Nil)
    }),
    before_each(fn() {
      io.println("  outer before_each")
      Ok(Nil)
    }),
    after_each(fn() {
      io.println("  outer after_each")
      Ok(Nil)
    }),
    after_all(fn() {
      io.println("outer after_all")
      Ok(Nil)
    }),
    group("Inner", [
      before_each(fn() {
        io.println("    inner before_each")
        Ok(Nil)
      }),
      after_each(fn() {
        io.println("    inner after_each")
        Ok(Nil)
      }),
      it("runs in the middle", fn() {
        io.println("      the test body")
        Ok(succeed())
      }),
    ]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

Its `main` prints this, and the exit status is 0:

### The hooks in their order <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_hooks_order.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
outer before_all
  outer before_each
    inner before_each
      the test body
    inner after_each
  outer after_each
outer after_all
Outer
  Inner
    ✓ runs in the middle

Summary: 1 run, 0 failed, 1 passed in 0ms
```

Setup runs from the outside in, and teardown from the inside out, like nested brackets. Each `before_each` of every group around the test runs, outermost first. Each `after_each` runs innermost first. `before_all` and `after_all` wrap the whole group.

## Step 3: Set up once for a whole run

Some setup belongs to the run, not to a suite: start a database server once, make a schema for each suite, log each test. Runner hooks do that without touching the suites. They go on the runner in `main`:

### Hooks for the whole run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/hooks_runner_hooks.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/types.{type SuiteInfo, type TestInfo}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/io
import gleam/list
import gleam/string

pub fn cart_tests() {
  describe("Cart", [
    it("starts empty", fn() { Ok(succeed()) }),
    it("adds an item", fn() { Ok(succeed()) }),
  ])
}

pub fn checkout_tests() {
  describe("Checkout", [
    it("charges the card", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  runner.new([cart_tests(), checkout_tests()])
  |> runner.max_concurrency(1)
  |> runner.before_all_suites(start_database)
  |> runner.after_all_suites(stop_database)
  |> runner.before_each_suite(create_schema)
  |> runner.before_each_test(log_test)
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

fn start_database(suites: List(SuiteInfo)) -> Result(Nil, String) {
  io.println(
    "start the database for " <> int.to_string(list.length(suites)) <> " suites",
  )
  Ok(Nil)
}

fn stop_database(_suites: List(SuiteInfo)) -> Result(Nil, String) {
  io.println("stop the database")
  Ok(Nil)
}

fn create_schema(suite: SuiteInfo) -> Result(Nil, String) {
  io.println("  create a schema for " <> suite.name)
  Ok(Nil)
}

fn log_test(info: TestInfo) -> Result(Nil, String) {
  io.println(
    "    run " <> string.join(types.full_name(info.groups, info.name), " > "),
  )
  Ok(Nil)
}
```

The run prints:

### The runner hooks around two suites <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_hooks_runner_hooks.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
start the database for 2 suites
  create a schema for Cart
    run Cart > starts empty
    run Cart > adds an item
  create a schema for Checkout
    run Checkout > charges the card
stop the database
Cart
  ✓ starts empty
  ✓ adds an item
Checkout
  ✓ charges the card

Summary: 3 run, 0 failed, 3 passed in 0ms
```

What each runner hook gets:

- `before_all_suites` and `after_all_suites` get the list of `SuiteInfo` of the run, after filtering.
- `before_each_suite` and `after_each_suite` get one `SuiteInfo`: `name`, the top-level group name; `tests`, the `TestInfo` of each test that will run; and `source`.
- `before_each_test` and `after_each_test` get one `TestInfo`: `name`, `groups` (outermost first), `tags` (with the tags of the groups), `kind` (`Unit`, or `GherkinScenario(scenario_id:, feature:, rule:)` for a scenario) and `source`. `types.full_name(info.groups, info.name)` gives the whole path, as in `Cart > starts empty`.

Every runner hook returns `Result(Nil, String)`. The test hooks don't get the context of the test: one run can hold suites with different context types.

`source` is best effort. For a suite from module discovery, it's the Erlang module name, for example `unit@cart_test` for `test/unit/cart_test.gleam`. For a Gherkin suite from feature discovery, it's the `.feature` path, also when a discovered module returns that suite. A suite you build by hand has `None`.

This example sets `runner.max_concurrency(1)` so the `run` lines come out in a fixed order for this page. With the default, the tests of a group run at the same time, and their `before_each_test` lines can come in any order.

## When a setup hook fails

A setup hook fails when it returns `Error(message)`, crashes or times out. The tests it serves don't run, and each one gets the status `SetupFailed`:

### A before_each hook that fails <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/hooks/setup_failure.gleam#L8-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn setup_failure_tests() {
  describe("Setup failures", [
    before_each(fn() { Error("could not connect to database") }),
    it("will not run", fn() {
      // This won't execute.
      io.println("nope")
      Ok(succeed())
    }),
  ])
}
```

### The report of a failed setup <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_hooks_setup_failure.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Setup failures
  ⚠ will not run
    before_each
      Message: could not connect to database
    Run it alone: gleam test -- --only "Setup failures/will not run"

Failures:
Setup failures
  ⚠ will not run
    before_each
      Message: could not connect to database
    Run it alone: gleam test -- --only "Setup failures/will not run"

Summary: 1 run, 0 failed, 0 passed, 1 setup failed in 0ms
```

`⚠` marks a test whose setup failed, the line under it names the hook, and the summary counts it as `setup failed`. The run fails. The teardown hooks of the levels that already started still run, so a `before_all` that worked gets its `after_all`.

The same rule holds for every setup hook: `before_all`, `before_each`, a context setup, and the runner hooks `before_each_test`, `before_each_suite` and `before_all_suites`.

## When a teardown hook fails

A teardown hook that fails can't undo a test that already passed, so the tests keep their status. The failure goes into its own list in the run report, and the run fails:

### An after_all hook that fails <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/hooks/teardown_failure.gleam#L7-L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn cleanup_failure_tests() {
  describe("Database", [
    after_all(fn() { Error("could not drop the test schema") }),
    it("saves a user", fn() { Ok(succeed()) }),
  ])
}
```

### The report of a failed teardown <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_hooks_teardown_failure.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Database
  ✓ saves a user

Setup and teardown failures:
  after_all in Database
    could not drop the test schema

Summary: 1 run, 0 failed, 1 passed, 1 teardown failed in 0ms
```

The test passed, and `Setup and teardown failures:` names the hook, where it ran and its message. The summary counts `1 teardown failed`, and with `runner.exit_on_failure()` the exit status is 1. Every other teardown hook still runs. In code, `types.report_hook_failures(report)` gives the failures as `TeardownFailed(hook:, path:, message:)` values, and the JSON reporter writes them in `hook_failures`.

This holds for `after_each`, `after_all`, a context teardown, and the runner hooks `after_each_test`, `after_each_suite` and `after_all_suites`.

## When a hook hangs

The runner waits for each hook as long as the default timeout, 5000 ms unless you set `runner.default_timeout_ms`. A setup hook that doesn't return in time fails the tests it serves, and the run goes on. Here `before_all` sleeps for a second, and the run allows 200 ms. The module also checks its own report, in `tests()`:

### A setup hook slower than the timeout <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/hooks_slow_setup.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/summary
import dream_test/runner
import dream_test/types.{type RunReport}
import dream_test/unit.{before_all, describe, it}
import gleam/erlang/process

/// A suite whose `before_all` hook waits longer than the timeout.
pub fn slow_setup_tests() {
  describe("Search index", [
    before_all(fn() {
      process.sleep(1000)
      Ok(Nil)
    }),
    it("finds a document", fn() { Ok(succeed()) }),
  ])
}

pub fn run_with_a_short_timeout() -> RunReport {
  runner.new([slow_setup_tests()])
  |> runner.default_timeout_ms(200)
  |> runner.silent()
  |> runner.run()
}

pub fn tests() {
  describe("A setup hook slower than the timeout", [
    it("gives SetupFailed", fn() {
      // Act
      let report = run_with_a_short_timeout()

      // Assert
      summary.count(report).setup_failed
      |> should
      |> be_equal(1)
      |> or_fail_with("the test should be SetupFailed")
    }),
  ])
}
```

### The report of a setup that timed out <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_hooks_timeout.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Search index
  ⚠ finds a document
    before_all
      Message: hook timed out in Search index
    Run it alone: gleam test -- --only "Search index/finds a document"

Failures:
Search index
  ⚠ finds a document
    before_all
      Message: hook timed out in Search index
    Run it alone: gleam test -- --only "Search index/finds a document"

Summary: 1 run, 0 failed, 0 passed, 1 setup failed in 0ms
```

The message names the hook level and the groups: `hook timed out in Search index`. A teardown hook that hangs is a teardown failure with the same kind of message. The [reference](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reference.md#hook-timeouts-and-crashes) lists the message of each hook level.

## Which process runs each hook

On the BEAM, a resource often lives as long as the process that started it: an ETS table, a linked actor, a connection pool. So it matters which process runs a hook. Each scope has one process that runs its hooks and lives as long as the tests it serves:

| Hooks | Process | Timeout |
|---|---|---|
| `before_all_suites`, `after_all_suites` | one setup process for the whole run | the default timeout, for each hook |
| `before_each_suite`, `after_each_suite` | one setup process for each suite | the default timeout of the suite, for each hook |
| the context setup and teardown (`context.setup`, `steps.new_with_setup`) | one setup process for each tree that has them, started after `before_each_suite` | the default timeout of the suite, for each |
| `before_all`, `after_all` | one setup process for each group | the default timeout, for each hook |
| `before_each_test`, `before_each`, the body, `after_each`, `after_each_test` | one process for each test | the default timeout for each hook, the test timeout for the body |

What follows from it:

- A pool that `before_all` starts lives until `after_all` stops it. A pool that `before_each` starts lives for the body and the `after_each` hooks of that test, so a hook can make a subject and the test body can receive from it.
- When the tests a setup serves end, its setup process exits with reason `shutdown`. An ETS table it made is deleted, and every linked process stops.
- When a test ends, its process exits with reason `shutdown`, or is killed on a timeout. An ETS table the test made is deleted, and linked processes that don't trap exits stop.
- If the body times out or its process stops, the `after_each` and `after_each_test` hooks that didn't run yet still run, in a new process.
- If the process that keeps a setup alive exits while its tests run, for example because a process linked to it crashed, the setup stopped. The tests that hadn't started are `SetupFailed`, the run report gets a `types.SetupStopped`, and the teardown hooks still run in a new process.

The [reference](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reference.md#hook-processes) has the full rules for crashes, timeouts and stopped setups, with each message.

Hooks don't make tests run one at a time. The tests of a group still run in parallel (four at a time by default), so hooks that share an outside resource, such as a port, a folder or a database schema, need isolated resources for each test, or a run with lower concurrency. [Run a large suite fast and predictably](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md) shows both.

## Test your code

A teardown hook that doesn't clean up passes every test and leaves a mess for the next run. You can check it: run the suite silently, then look at the world it left behind.

### Check that the cleanup hook cleans up <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/hooks_check_cleanup.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/file.{NotFound}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/unit.{describe, it}
import snippets/guides/hooks_user_files.{alice_file}

pub fn tests() {
  describe("The user file hooks", [
    it("remove the file after the last test", fn() {
      // Arrange
      let suite = hooks_user_files.tests()

      // Act
      runner.new([suite])
      |> runner.silent()
      |> runner.run()
      let after_the_run = file.read(alice_file)

      // Assert
      after_the_run
      |> should
      |> be_equal(Error(NotFound(alice_file)))
      |> or_fail_with("after_all should delete the file")
    }),
  ])
}
```

After the run, the file must be gone, so `file.read` gives exactly `Error(NotFound(alice_file))`. If someone removes the `after_all`, this test fails and shows the file's content in place of the error. The report:

### The report of the cleanup check <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_hooks_check.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
The user file hooks
  ✓ remove the file after the last test

Summary: 1 run, 0 failed, 1 passed in 0ms
```

The same shape tests any hook: run the suite with `runner.silent()`, then check what the hooks did, or check the report with `types.report_hook_failures`.

## Common pitfalls

**A test that depends on another test.** *Symptom:* a test passes alone and fails in the full run, or the other way round. *Fix:* tests of a group run in parallel and in no fixed order. Put shared setup in `before_all` or `before_each`, never in another test.

**Setup that hides the point of a test.** *Symptom:* you read a test and can't tell what it checks without reading three hooks. *Fix:* keep the setup the assertion depends on in the test body. Use hooks for infrastructure.

**A resource that stops too soon.** *Symptom:* a process or ETS table that `before_all` made is gone in the tests, or one that `before_each` made is gone in a later test. *Fix:* match the hook to the lifetime you need, using [the process table](#which-process-runs-each-hook).

**An empty group for a hook.** *Symptom:* a `before_all` in a group with no tests never runs. *Fix:* hooks run only for tests that run. Put the hook in a group with tests, or use a runner hook.

**A slow setup with the default timeout.** *Symptom:* `hook timed out in ...` on a slow CI machine. *Fix:* raise `runner.default_timeout_ms`, or set a timeout for the suites that need it with `runner.add_suites_with_config`.

## Where to go next

- [Share a context between tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/context-aware-tests.md): a setup that hands a value to every test.
- [Run a large suite fast and predictably](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md): timeouts, concurrency and the exit status.
- [Reference](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reference.md#hook-processes): the full rules of hook processes, crashes and timeouts.
- [API reference on HexDocs](https://hexdocs.pm/dream_test/dream_test/unit.html): `before_all`, `before_each`, `after_each`, `after_all`, and the runner hooks in `dream_test/runner`.
