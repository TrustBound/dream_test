# dream_test Test Author Interface

This document describes the **interface a user writes tests with**.

It focuses on:
- How to **define tests** (the unit test DSL).
- How to **make assertions**.
- How those pieces fit together today.

Internal modules such as `dream_test/types`, `dream_test/assertions/context`, `dream_test/runner`, and anything under `dream_test/bootstrap` are **not** part of the public interface and may change. They are used behind the scenes.

---

## 1. Your First Test Module

This is the **intended** interface for test authors: minimal ceremony, close to Jest/RSpec.

```gleam
import gleam/int
import dream_test/unit.{describe, it}
import dream_test/assertions/should

pub fn tests() {
  describe("Math & Parsing", [
    it("adds numbers", fn() {
      let sum = 1 + 2

      sum
      |> should.equal(3)
      |> should.or_fail_with("1 + 2 should equal 3")
    }),

    it("parses integers", fn() {
      int.parse("123")
      |> should.equal(123)
      |> should.or_fail_with("Should parse 123 from string")
    }),
  ])
}
```

Key ideas:
- Test bodies are **inline** anonymous functions with no explicit context argument.
- You define tests with `describe` and `it` from `dream_test/unit` and do **not** see `TestCase`, `UnitTest`, or runner details.
- Assertions use `should.equal` and `should.or_fail_with` from the `dream_test/assertions/should` module.

The runner/CLI (or current harness) is responsible for discovering `tests()` functions in test modules, converting the description tree into concrete test cases, and executing them.

---

## 2. Defining Tests with `describe` and `it`

The **unit test DSL** lives in `dream_test/unit`.

### 2.1 Imports

```gleam
import dream_test/unit.{describe, it}
import dream_test/assertions/should
```

### 2.2 Writing inline test bodies

Each test body is an anonymous function `fn() { ... }`:

```gleam
pub fn tests() {
  describe("Math", [
    it("adds numbers", fn() {
      add(1, 2)
      |> should.equal(3)
      |> should.or_fail_with("1 + 2 should equal 3")
    }),

    it("subtracts numbers", fn() {
      subtract(4, 1)
      |> should.equal(3)
      |> should.or_fail_with("4 - 1 should equal 3")
    }),
  ])
}
```

You can nest `describe` blocks to build hierarchical names:

```gleam
pub fn tests() {
  describe("Math", [
    describe("addition", [
      it("adds positive numbers", fn(context: TestContext(Int)) {
        add(1, 2)
        |> should.equal(context, 3)
        |> should.or_fail_with("1 + 2 should equal 3")
      }),
    ]),
  ])
}
```

---

## 3. Making Assertions with `should`

Assertions are provided by `dream_test/assertions/should` and operate on values, returning an `AssertionResult`.

### 3.1 Imports

Following the project standards:

```gleam
import dream_test/assertions/should
```

### 3.2 Pattern: equal + or_fail_with

```gleam
fn greets_user(name: String) {
  let greeting = make_greeting(name)

  greeting
  |> should.equal("Hello, " <> name)
  |> should.or_fail_with("Should greet the user by name")
}
```

You typically do not need to inspect `AssertionResult` directly in test code; the runner converts failures into `AssertionFailure` values internally.

---

## 4. How Tests Run (Today and Later)

**From the test author’s perspective**, you only:

1. Write `pub fn tests()` in your test modules.
2. Use `describe` / `it` / `should` as shown above.

Internally, for now, the framework will:

1. Build a `UnitTest(a)` tree from `describe` / `it` (see `dream_test/unit`).
2. Convert it to `List(TestCase(a))` with `to_test_cases(module_name, root)`.
3. Execute those `TestCase`s with `run_all`, which calls `fn() -> AssertionResult(a)` test bodies and converts them into `TestResult(a)` values.

The project’s `Makefile` runs the current bootstrap checks and test harness via:

```sh
make all
```

As the framework evolves, a CLI and automatic test discovery will hide the `UnitTest` / `TestCase` / `AssertionResult` details completely; this document will continue to describe only the `describe` / `it` / `should` surface that test authors use.

---

## 5. What You Do **Not** Need to Use

These modules are internal implementation details and are intentionally **not** part of the stable test author interface:

- `dream_test/types`
- `dream_test/assertions/context` (beyond importing `TestContext`, `new`, and `failures` as shown above)
- `dream_test/runner` (beyond importing `TestCase` and `run_all` until a higher‑level CLI exists)
- Any module under `dream_test/bootstrap`

They are documented in `DESIGN.md` and `ARCHITECTURE.md` for maintainers, but are free to change without breaking the user‑facing DSL and assertions shown here.

This document shows **concrete usage examples** for the functionality that currently exists in the `dream_test` codebase.

It is intentionally **implementation-accurate**:
- Imports match the actual module structure and project import standards.
- Examples only use functions and types that are already implemented.

Currently implemented, user-facing pieces:
- Core types: `dream_test/types`
- Assertion helpers: `dream_test/assertions/should`
- Unit test DSL: `dream_test/unit`
- (The runner and bootstrap assertions are internal and invoked by the framework.)

Bootstrap modules under `dream_test/bootstrap` are **internal** sanity checks and are not part of the public interface, but we reference them where they illustrate real usage.

---

## 1. Core Types (`dream_test/types`)

The `dream_test/types` module defines shared data types used across the framework.

### 1.1 Importing and constructing core types

```gleam
import dream_test/types

pub fn example_location() {
  let location = types.Location(
    module_: "my_module", 
    file: "test/my_module_test.gleam", 
    line: 42,
  )

  location
}
```

You can also import specific names if you prefer unqualified usage:

```gleam
import dream_test/types.{Location, Status, AssertionFailure, TestResult}

pub fn example_values() {
  let location = Location("example_module", "example.gleam", 10)

  let status = Status.Passed

  let failure: AssertionFailure(Int) = AssertionFailure(
    actual: 1,
    expected: 2,
    operator: "equal",
    message: "1 should equal 2 (example)",
    location: location,
  )

  let result: TestResult(Int) = TestResult(
    name: "example test",
    full_name: ["Example", "test"],
    status: status,
    duration_ms: 0,
    tags: ["example"],
    failures: [failure],
    location: location,
    kind: types.Unit,
  )

  result
}
```

### 1.2 Deriving status from failures

```gleam
import dream_test/types.{type AssertionFailure, AssertionFailure, Status, status_from_failures}

pub fn example_status() {
  let location = Location("example_module", "example.gleam", 10)

  let no_failures: List(AssertionFailure(Int)) = []
  let empty_status = status_from_failures(no_failures)
  // empty_status == Status.Passed

  let some_failure = AssertionFailure(
    actual: 1,
    expected: 2,
    operator: "equal",
    message: "",
    location: location,
  )

  let non_empty_failures = [some_failure]
  let failed_status = status_from_failures(non_empty_failures)
  // failed_status == Status.Failed

  failed_status
}
```

---

## 2. Assertion Context (`dream_test/assertions/context`)

`TestContext` is the per-test state that tracks failures.

### 2.1 Basic usage

```gleam
import dream_test/assertions/context.{type TestContext, TestContext, new, failures, add_failure}
import dream_test/types.{AssertionFailure, Location}

pub fn context_example() {
  let initial_context: TestContext(Int) = new()

  let location = Location("context_example", "example.gleam", 0)

  let failure = AssertionFailure(
    actual: 1,
    expected: 2,
    operator: "equal",
    message: "Numbers did not match",
    location: location,
  )

  let updated_context = add_failure(initial_context, failure)
  let recorded_failures = failures(updated_context)

  recorded_failures
}
```

This mirrors how the bootstrap modules build failures and add them to a `TestContext`.

---

## 3. Assertion Helpers (`dream_test/assertions/should`)

The `should` module provides **pipe-first** helpers that operate on a `TestContext`.

Currently implemented:
- `equal(actual, context, expected) -> TestContext(a)`
- `or_fail_with(test_context, message) -> TestContext(a)`

### 3.1 Imports

Recommended imports (following `STANDARDS.md` and `AGENTS.md`):

```gleam
import dream_test/assertions/context.{type TestContext, new, failures}
import dream_test/assertions/should.{or_fail_with}
```

You can then refer to `should.equal` fully-qualified while using `or_fail_with` unqualified.

### 3.2 Using `equal` and `or_fail_with` together

```gleam
import dream_test/assertions/context.{type TestContext, new, failures}
import dream_test/assertions/should.{or_fail_with}

pub fn example_assertions() {
  let initial_context: TestContext(Int) = new()

  // Passing assertion: does not add failures
  let context_after_pass =
    3
    |> should.equal(initial_context, 3)

  let passing_failures = failures(context_after_pass)
  // passing_failures == []

  // Failing assertion: adds a failure
  let context_after_fail =
    3
    |> should.equal(initial_context, 4)

  let failing_failures = failures(context_after_fail)

  // Override the failure message for the most recent failure
  let context_with_custom_message =
    3
    |> should.equal(initial_context, 4)
    |> or_fail_with("Custom failure message")

  context_with_custom_message
}
```

This is the same pattern used in `bootstrap_should.gleam`.

---

## 4. Runner Core (`dream_test/runner`)

The runner executes test functions that operate on `TestContext` and produces `TestResult` values.

Currently implemented:
- `SingleTestConfig(a)` type
- `TestCase(a)` type
- `run_single_test(config) -> TestResult(a)`
- `run_test_case(test_case) -> TestResult(a)`
- `run_all(test_cases) -> List(TestResult(a))`

### 4.1 Running a single test

```gleam
import dream_test/assertions/context.{type TestContext, add_failure}
import dream_test/bootstrap/core_assert
import dream_test/types.{AssertionFailure, Location, Unit, Passed, Failed}
import dream_test/runner.{SingleTestConfig, run_single_test}

fn example_passing_test(context: TestContext(Int)) -> TestContext(Int) {
  context
}

fn example_failing_test(context: TestContext(Int)) -> TestContext(Int) {
  let failure = AssertionFailure(
    actual: 1,
    expected: 2,
    operator: "equal",
    message: "",
    location: Location("example_runner", "example_runner.gleam", 0),
  )

  add_failure(context, failure)
}

pub fn example_runner_single() {
  let module_name = "example_runner"
  let common_full_name = ["examples", "runner"]
  let common_tags = ["example", "runner"]
  let common_location = Location(module_name, "example_runner.gleam", 0)

  let passing_config = SingleTestConfig(
    name: "passing test",
    full_name: common_full_name,
    tags: common_tags,
    kind: Unit,
    location: common_location,
    run: example_passing_test,
  )

  let passing_result = run_single_test(passing_config)

  // passing_result.status == Passed
  // passing_result.failures == []

  passing_result
}
```

### 4.2 Running a small suite with `run_all`

```gleam
import dream_test/assertions/context.{type TestContext, add_failure}
import dream_test/types.{AssertionFailure, Location, Unit}
import dream_test/runner.{type TestCase, TestCase, SingleTestConfig, run_all}

fn suite_passing_test(context: TestContext(Int)) -> TestContext(Int) {
  context
}

fn suite_failing_test(context: TestContext(Int)) -> TestContext(Int) {
  let failure = AssertionFailure(
    actual: 1,
    expected: 2,
    operator: "equal",
    message: "",
    location: Location("example_runner_suite", "example_runner_suite.gleam", 0),
  )

  add_failure(context, failure)
}

pub fn example_runner_suite() {
  let module_name = "example_runner_suite"
  let common_full_name = ["examples", "runner_suite"]
  let common_tags = ["example", "runner"]
  let common_location = Location(module_name, "example_runner_suite.gleam", 0)

  let passing_config = SingleTestConfig(
    name: "passing test",
    full_name: common_full_name,
    tags: common_tags,
    kind: Unit,
    location: common_location,
    run: suite_passing_test,
  )

  let failing_config = SingleTestConfig(
    name: "failing test",
    full_name: common_full_name,
    tags: common_tags,
    kind: Unit,
    location: common_location,
    run: suite_failing_test,
  )

  let test_cases: List(TestCase(Int)) = [
    TestCase(passing_config),
    TestCase(failing_config),
  ]

  let results = run_all(test_cases)

  results
}
```

These examples are directly based on `bootstrap_runner_core.gleam` and `bootstrap_runner_suite.gleam`.

---

## 5. Unit Test DSL (`dream_test/unit`)

The `unit` module provides a small DSL for defining unit tests and converting them into runner `TestCase` values.

Currently implemented:
- `UnitTest(a)` type (`ItTest` and `DescribeGroup` constructors)
- `it(name, run) -> UnitTest(a)`
- `describe(name, children) -> UnitTest(a)`
- `to_test_cases(module_name, root) -> List(TestCase(a))`

### 5.1 Defining tests with `describe` and `it`

```gleam
import dream_test/assertions/context.{type TestContext}
import dream_test/unit.{describe, it, type UnitTest, to_test_cases}
import dream_test/runner.{type TestCase, run_all}

fn adds_numbers_test(context: TestContext(Int)) -> TestContext(Int) {
  // Real assertions would go here using `should`.
  context
}

fn subtracts_numbers_test(context: TestContext(Int)) -> TestContext(Int) {
  // Real assertions would go here using `should`.
  context
}

pub fn example_unit_dsl_run() {
  let tests: UnitTest(Int) =
    describe("Math", [
      it("adds numbers", adds_numbers_test),
      it("subtracts numbers", subtracts_numbers_test),
    ])

  // Translate the DSL tree into concrete TestCase values
  let test_cases: List(TestCase(Int)) =
    to_test_cases("example_unit_dsl", tests)

  // Run all tests through the runner
  let results = run_all(test_cases)

  results
}
```

This is equivalent in shape to `bootstrap_unit_dsl.gleam`, but written as a reusable function rather than a bootstrap `main`.

---

## 6. Putting It Together: A Minimal End-to-End Example

This section shows how a user could **today**:
- Define a small test tree using the unit DSL.
- Use `should.equal` and `or_fail_with` for assertions.
- Run those tests through the runner.

```gleam
import gleam/int
import dream_test/types.{Location, Unit}
import dream_test/assertions/context.{type TestContext, new}
import dream_test/assertions/should.{or_fail_with}
import dream_test/unit.{describe, it, type UnitTest, to_test_cases}
import dream_test/runner.{type TestCase, run_all}

fn adds_numbers(context: TestContext(Int)) -> TestContext(Int) {
  let sum = 1 + 2

  sum
  |> should.equal(context, 3)
  |> or_fail_with("1 + 2 should equal 3")
}

fn parses_int(context: TestContext(Int)) -> TestContext(Int) {
  let parsed = int.parse("123")

  case parsed {
    Ok(value) ->
      value
      |> should.equal(context, 123)
      |> or_fail_with("Should parse 123 from string")

    Error(_) ->
      // Force a failure by comparing mismatched values
      0
      |> should.equal(context, 1)
      |> or_fail_with("Parsing int from string failed unexpectedly")
  }
}

pub fn run_example_suite() {
  let tests: UnitTest(Int) =
    describe("Math & Parsing", [
      it("adds numbers", adds_numbers),
      it("parses integers", parses_int),
    ])

  let test_cases: List(TestCase(Int)) =
    to_test_cases("example_suite", tests)

  let results = run_all(test_cases)

  results
}
```

This example stays within the currently implemented API surface and respects the project’s import conventions.
