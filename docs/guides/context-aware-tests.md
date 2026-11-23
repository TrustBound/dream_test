# Share a context between tests

Plain hooks return `Ok(Nil)`, so they can make a file or start a server, but they can't hand anything to the tests. Real setups make values: a database connection, the subject of a process, a client with a token. You want each test to get that value as an argument, with its type checked by the compiler, not fished out of a global. That's what a context does in Dream Test. This guide shows how to pass a value to every test, how to change it in hooks, how to start a resource once and stop it after the last test, and what the report says when that setup fails.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which kind of suite to use](#which-kind-of-suite-to-use)
- [Step 1: Switch to the context DSL](#step-1-switch-to-the-context-dsl)
- [Step 2: Change the context in hooks](#step-2-change-the-context-in-hooks)
- [Step 3: Get the context from a setup](#step-3-get-the-context-from-a-setup)
- [Step 4: Run context suites with other suites](#step-4-run-context-suites-with-other-suites)
- [When the setup fails](#when-the-setup-fails)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you'll:

- Give a suite a starting value that every test receives.
- Change that value in `before_each` hooks, with nested groups.
- Start a user store process once for a suite, hand it to every test, and stop it after the last one.
- Read the report of a setup that can't start the store.
- Test the setup and teardown functions on their own.

## Before you start

You need Dream Test as a dev dependency and a test runner module. [Write and run your first test](https://github.com/TrustBound/dream_test/blob/main/docs/guides/getting-started.md) sets both up, and [Set up and tear down around tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/lifecycle-hooks.md) explains hooks.

```sh
gleam add --dev dream_test
```

The store example uses `gleam_erlang` for processes. The outputs on this page are real outputs of the code shown, with every time set to 0, so they stay the same from run to run.

## Which kind of suite to use

| Your situation | Use | Why |
|:---|:---|:---|
| The tests need no shared value | `dream_test/unit` | The simplest. Hooks return `Ok(Nil)`. |
| The tests share a value you can build up front, and hooks change it | `unit_context.describe(name, initial, children)` | Every hook and test gets the value. |
| The value comes from a setup that must run once and be undone, such as a process or a pool | `unit_context.describe_with_setup(name:, setup:, teardown:, children:)` | The setup runs once, its value is the context, and the teardown gets it after the last test. |
| Gherkin scenarios that share a server | `steps.new_with_setup` | The same idea for features. See [Write Gherkin features](https://github.com/TrustBound/dream_test/blob/main/docs/guides/gherkin-bdd.md#step-6-start-a-server-once-for-all-scenarios). |

When the setup is tiny and reads well inside the test, stay with `unit`. A context earns its place when the setup makes a value that many tests use.

## Step 1: Switch to the context DSL

`dream_test/unit_context` has the same names as `dream_test/unit`: `describe`, `group`, `it`, `skip`, `pending`, the four hooks and `with_tags`. Switching is mostly a change of import:

### The unit import <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/unit/dsl_import.gleam#L2"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/unit.{describe, it}
```

### The unit_context import <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/hooks/context_dsl_import.gleam#L2"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/unit_context.{describe, it}
```

Two things change. `describe` takes a starting value, `describe(name, initial, children)`, and each `it` body takes the context, `it(name, fn(context) { ... })`. Pick one DSL for each test module: if you import the unqualified names of both, `describe` and `it` clash.

Why the starting value? Gleam must know the type of the context when it checks `fn(context) { ... }`, and the suite is built before any hook runs. The `initial` value fixes that type when the suite is built, so every hook and test is type-checked against it. No hook has to be "the one that makes the context".

## Step 2: Change the context in hooks

In a context suite, `before_each` gets the context and returns `Ok(new_context)`. Each test gets the context after all its `before_each` hooks ran. This suite counts the hooks:

### A counter context <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/hooks/context_aware_tests.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit_context.{before_each, describe, group, it}

pub type Context {
  Context(counter: Int)
}

fn increment_counter(context: Context) {
  Ok(Context(counter: context.counter + 1))
}

pub fn tests() {
  describe("Context-aware suite", Context(counter: 0), [
    before_each(increment_counter),
    it("receives the updated context", fn(context: Context) {
      context.counter
      |> should
      |> be_equal(1)
      |> or_fail_with("expected counter to be 1 after before_each")
    }),
    // A hook applies to every test of its group, wherever it is in the
    // list. To add a hook for some tests only, put them in a nested group.
    group("with a second hook", [
      before_each(increment_counter),
      it("sees both hooks", fn(context: Context) {
        context.counter
        |> should
        |> be_equal(2)
        |> or_fail_with("expected counter to be 2 after two before_each hooks")
      }),
    ]),
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

Both tests pass:

### The report of the counter suite <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_context_counter.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Context-aware suite
  ✓ receives the updated context
  with a second hook
    ✓ sees both hooks

Summary: 2 run, 0 failed, 2 passed in 0ms
```

The first test sees `1`: one hook ran. The test in the nested group sees `2`: the outer hook ran, then its own. A hook of an outer group applies to every test in it, also in nested groups, and a hook of an inner group only to the tests of that group. A hook applies to its whole group, wherever it stands in the list.

Each test starts from the same value. A change that one test's hooks make never reaches another test, so the tests can run in parallel.

Note the annotation `fn(context: Context)`. Gleam lets you read a record field such as `context.counter` only when it knows the record type, and an anonymous function doesn't always give it enough to infer it. The annotation is the smallest hint that makes `context.counter` compile.

## Step 3: Get the context from a setup

A counter you can write up front. A running process you can't: something has to start it, and something has to stop it. `describe_with_setup` takes a `setup` function that returns `Ok(context)`, and a `teardown` function that gets the context back. Here the setup starts a user store, a small process that holds names by id:

### A store that every test gets <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/context_store.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit_context.{before_each, describe_with_setup, it}
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}

/// A message to the user store: a small process that holds names by id.
pub type Message {
  Put(id: Int, name: String)
  Get(id: Int, reply_to: Subject(Result(String, Nil)))
  Stop
}

/// Starts the store, and gives the subject to send it messages.
pub fn start_store() -> Result(Subject(Message), String) {
  let started = process.new_subject()
  process.spawn(fn() { serve(started) })
  case process.receive(started, 1000) {
    Ok(store) -> Ok(store)
    Error(Nil) -> Error("the store did not start")
  }
}

pub fn stop_store(store: Subject(Message)) -> Result(Nil, String) {
  process.send(store, Stop)
  Ok(Nil)
}

fn serve(started: Subject(Subject(Message))) -> Nil {
  let messages = process.new_subject()
  process.send(started, messages)
  answer(messages, dict.new())
}

fn answer(messages: Subject(Message), names: Dict(Int, String)) -> Nil {
  case process.receive_forever(messages) {
    Put(id:, name:) -> answer(messages, dict.insert(names, id, name))
    Get(id:, reply_to:) -> {
      process.send(reply_to, dict.get(names, id))
      answer(messages, names)
    }
    Stop -> Nil
  }
}

pub fn tests() {
  describe_with_setup(
    "User store",
    setup: start_store,
    teardown: stop_store,
    children: [
      before_each(put_alice),
      it("finds a user by id", fn(store: Subject(Message)) {
        process.call(store, 1000, Get(1, _))
        |> should
        |> be_equal(Ok("Alice"))
        |> or_fail_with("the store should hold Alice as user 1")
      }),
      it("has no user 2", fn(store: Subject(Message)) {
        process.call(store, 1000, Get(2, _))
        |> should
        |> be_equal(Error(Nil))
        |> or_fail_with("the store should not hold user 2")
      }),
    ],
  )
}

fn put_alice(store: Subject(Message)) -> Result(Subject(Message), String) {
  process.send(store, Put(1, "Alice"))
  Ok(store)
}
```

### The report of the store suite <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_context_store.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
User store
  ✓ finds a user by id
  ✓ has no user 2

Summary: 2 run, 0 failed, 2 passed in 0ms
```

How the setup runs. The reports call it the *context setup*, and the teardown the *context teardown*:

- The setup runs once for the tests of this `describe_with_setup`, before the first of them, and only when at least one of them runs.
- Its value is the context of every hook and test. Here every test gets the store's `Subject`, and `before_each(put_alice)` uses it to add a user before each test.
- The teardown gets the same value after the last test.
- The setup and the teardown run in one process that lives while the tests run. So the store, which the setup spawned, stays alive for every test, and stops only when the teardown sends `Stop`.

The tests run in parallel against the one store, so each test must leave the others alone. Here every test reads the user that `before_each` writes, and no test changes it.

## Step 4: Run context suites with other suites

The context stays inside the suite, so a context suite has the same type as any other: `TestSuite`. One `runner.new` takes `unit` suites, `unit_context` suites with different context types, and Gherkin features. Module discovery loads a context suite too, and runs it with its own context. [Write Gherkin features](https://github.com/TrustBound/dream_test/blob/main/docs/guides/gherkin-bdd.md#step-6-start-a-server-once-for-all-scenarios) shows a run with all three kinds.

`suite.group` and `suite.join` make one suite from several, and each keeps its context. Two `describe_with_setup` suites in one `suite.join` still run two setups, one for each.

## When the setup fails

The store might not start: the port is taken, the database is down. Make the setup return `Error(message)` and the tests don't run:

### A setup that cannot start the store <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/context_store_down.gleam#L8-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn store_down_tests() {
  describe_with_setup(
    "User store",
    setup: fn() { Error("the store did not start: port 7000 is in use") },
    teardown: fn(_store: Nil) { Ok(Nil) },
    children: [
      it("finds a user by id", fn(_store: Nil) {
        1
        |> should
        |> be_equal(1)
        |> or_fail_with("never runs")
      }),
    ],
  )
}
```

### The report of a failed context setup <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_context_store_down.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
User store
  ⚠ finds a user by id
    context setup
      Message: the store did not start: port 7000 is in use

Failures:
User store
  ⚠ finds a user by id
    context setup
      Message: the store did not start: port 7000 is in use

Summary: 1 run, 0 failed, 0 passed, 1 setup failed in 0ms
```

Each test is `SetupFailed`, the operator is `context setup`, and the message is the text of your `Error`. Make that text say what to fix. The teardown doesn't run, because there's no context to tear down. The run fails.

The other ways a context setup or teardown can fail:

- A setup that crashes gives the message `the context setup crashed in User store: <reason>`. One that times out gives `the context setup timed out in User store`.
- A teardown that returns `Error`, crashes or times out doesn't change the test statuses. The run report gets a teardown failure for the hook `context teardown`, and the report shows `context teardown in User store`, then the message, such as `the context teardown crashed in User store: <reason>`.
- When the process of the setup stops while the tests run, each test that hadn't started is `SetupFailed` with `not run: the context setup of "User store" stopped (<reason>)`. The run report gets a `types.SetupStopped` for the hook `context setup`, and the teardown still runs, because the setup returned.

## Test your code

The setup and the teardown are plain functions, so test them as plain functions. A setup that starts something broken makes every test of the suite fail in confusing ways, and a teardown that doesn't stop it leaks a process into every later test.

### Tests for the setup and the teardown <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/context_store_setup_tests.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, be_ok, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/erlang/process
import gleam/result
import snippets/guides/context_store.{Get, Put, start_store, stop_store}

pub fn tests() {
  describe("The user store setup", [
    it("starts a store that keeps what it gets", fn() {
      // Arrange
      use store <- result.try(start_store())
      process.send(store, Put(7, "Grace"))

      // Act
      let found = process.call(store, 1000, Get(7, _))
      use Nil <- result.try(stop_store(store))

      // Assert
      found
      |> should
      |> be_equal(Ok("Grace"))
      |> or_fail_with("the new store should give back user 7")
    }),
    it("stops the store in the teardown", fn() {
      // Arrange
      use store <- result.try(start_store())

      // Act
      let stopped = stop_store(store)

      // Assert
      stopped
      |> should
      |> be_ok()
      |> be_equal(Nil)
      |> or_fail_with("the teardown should succeed")
    }),
  ])
}
```

The first test starts a store, uses it, and stops it, so it checks that the store the setup gives really works. `use store <- result.try(start_store())` ends the test with the setup's error text if the store doesn't start. The second checks that the teardown returns `Ok(Nil)`. The report:

### The report of the setup tests <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_context_checks.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
The user store setup
  ✓ starts a store that keeps what it gets
  ✓ stops the store in the teardown

Summary: 2 run, 0 failed, 2 passed in 0ms
```

## Common pitfalls

**Both DSLs imported unqualified.** *Symptom:* the compiler says `describe` or `it` is imported twice. *Fix:* pick `unit` or `unit_context` for the module, or import one of them qualified.

**A field access that doesn't compile.** *Symptom:* `context.counter` gives an error about an unknown record type. *Fix:* annotate the parameter: `fn(context: Context)`.

**Tests that change a shared resource.** *Symptom:* tests of a `describe_with_setup` suite pass alone and fail together. *Fix:* the tests run in parallel against one resource. Give each test its own keys or rows, or run the suite with lower concurrency.

**A resource started in `before_all` of a context suite.** *Symptom:* you need the value in the tests, but `before_all` can only change the context of the group. *Fix:* start the resource in the `setup` of `describe_with_setup`, which runs once and hands its value to every test.

**A vague setup error.** *Symptom:* `Message: failed` under every test. *Fix:* return `Error` with what failed and why, as in `the store did not start: port 7000 is in use`.

## Where to go next

- [Set up and tear down around tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/lifecycle-hooks.md): the hooks of plain suites, and which process runs each one.
- [Write Gherkin features](https://github.com/TrustBound/dream_test/blob/main/docs/guides/gherkin-bdd.md): scenarios with a typed state and a shared setup.
- [Run a large suite fast and predictably](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md): concurrency for suites that share a resource.
- [API reference on HexDocs](https://hexdocs.pm/dream_test/dream_test/unit_context.html): `describe`, `describe_with_setup` and the rest of `unit_context`.
