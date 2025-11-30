# Dream Test Framework Architecture

This document expands on `DESIGN.md` with **concrete shapes and examples** for the main parts of the framework.

- Pipe-first assertions (`should`)
- Core types (`Location`, `AssertionFailure`, `TestResult`, `TestCase`)
- Runner and sandboxed supervisors
- Unit test DSL (`describe` / `it` / tags / hooks)
- Gherkin integration with `.feature` files and step definitions
- Reporters and CLI entrypoint

> All examples are illustrative and will evolve, but they show the intended developer experience and internal contracts.

---

## 1. Core Types

### 1.1 Location, status, tags

```gleam
pub type Location {
  Location(
    module_: String,
    file: String,
    line: Int,
  )
}

pub type Status {
  Passed
  Failed
  Skipped
  Pending
  TimedOut
}

pub type Tag =
  String
```

### 1.2 AssertionFailure

```gleam
pub type AssertionFailure(a) {
  AssertionFailure(
    actual: a,
    expected: a,
    operator: String,      // "equal", "contain", "be_greater_than", etc.
    message: String,       // user or default message
    location: Location,
  )
}
```

Examples:

- Failed equality assertion:

```gleam
AssertionFailure(
  actual: "Hi, Gleam",
  expected: "Hello, Gleam",
  operator: "equal",
  message: "Should have greeted properly",
  location: Location("user_test", "test/user_test.gleam", 12),
)
```

### 1.3 TestResult and TestCase

```gleam
pub type TestKind {
  Unit
  Integration
  GherkinScenario(String) // scenario id or path anchor
}

pub type TestResult(a) {
  TestResult(
    name: String,
    full_name: List(String),  // e.g. ["User", "registration", "creates a user"]
    status: Status,
    duration_ms: Int,
    tags: List(Tag),
    failures: List(AssertionFailure(a)),
    location: Location,
    kind: TestKind,
  )
}

pub type TestCase(a) {
  TestCase(
    name: String,
    full_name: List(String),
    tags: List(Tag),
    location: Location,
    kind: TestKind,
    run: fn() -> TestResult(a),
  )
}
```

**Example:** a simple unit test case:

```gleam
let location = Location("user_test", "test/user_test.gleam", 10)

let test_case = TestCase(
  name: "creates a user with valid data",
  full_name: ["User", "registration", "creates a user with valid data"],
  tags: ["unit", "user"],
  location: location,
  kind: Unit,
  run: fn() {
    // Test body and assertions here; produce TestResult
  },
)
```

---

## 2. Bootstrap Assertions (`core_assert`)

`core_assert` is a tiny internal module used to test the lowest-level core.

### 2.1 API

```gleam
pub fn equal(a expected: a, a actual: a, String message) {
  assert expected == actual as message
}

pub fn is_true(Bool cond, String message) {
  assert cond as message
}
```

### 2.2 Usage in bootstrap tests

```gleam
import core_assert
import test_core.{derive_status, Failed}

pub fn main() {
  let failures = [/* some AssertionFailure */]
  let status = derive_status(failures)

  core_assert.equal(Failed, status, "derive_status should return Failed when failures exist")
}
```

No runner is required here; tests can be executed via `main` or a small ad-hoc bootstrap harness.

---

## 3. Assertion Engine (`should`)

The public assertion engine is **pipe-first** and works with a `TestContext` shared across assertions in a single test.

### 3.1 TestContext

```gleam
pub type TestContext(a) {
  TestContext(
    failures: List(AssertionFailure(a)),
  )
}

pub fn new_context() -> TestContext(a) {
  TestContext(failures: [])
}
```

### 3.2 Core `should` functions

The public API will favour pipe-first usage, hiding most details from users.

Conceptually:

```gleam
pub fn equal(expected: a) -> fn(TestContext(a), a) -> TestContext(a)

pub fn or_fail_with(message: String) -> fn(TestContext(a)) -> TestContext(a)
```

**Example usage inside a test body:**

```gleam
import should

pub fn creates_greeting(ctx: TestContext(String)) -> TestContext(String) {
  let greeting = make_greeting("Gleam")

  greeting
  |> should.equal("Hello, Gleam")(ctx)
  |> should.or_fail_with("Should have shown Hello, Gleam")
}
```

### 3.3 How `equal` works internally (conceptually)

```gleam
pub fn equal(expected: a) -> fn(TestContext(a), a) -> TestContext(a) {
  fn(ctx, actual) {
    case actual == expected {
      True ->
        ctx

      False ->
        let failure = AssertionFailure(
          actual: actual,
          expected: expected,
          operator: "equal",
          message: "",
          location: /* captured via macros or passed in */, 
        )

        TestContext(failures: [failure, ..ctx.failures])
    }
  }
}
```

`or_fail_with` updates the message for the most recent failure in the context:

```gleam
pub fn or_fail_with(message: String) -> fn(TestContext(a)) -> TestContext(a) {
  fn(ctx) {
    case ctx.failures {
      [] -> ctx
      [first, ..rest] ->
        TestContext(failures: [AssertionFailure(..first, message: message), ..rest])
    }
  }
}
```

---

## 4. Runner and Sandboxed Supervisors

### 4.1 Conceptual runner API

```gleam
pub type CoverageMode {
  NoCoverage
  ModuleCoverage
  LineCoverage
}

pub type RunnerConfig {
  RunnerConfig(
    max_concurrency: Int,
    timeout_ms: Int,
    include_tags: List(Tag),
    exclude_tags: List(Tag),
    coverage_mode: CoverageMode,
    coverage_paths: List(String),
  )
}

pub type ModuleCoverage {
  ModuleCoverage(
    module_: String,
    percent: Float,
    covered_lines: Int,
    total_lines: Int,
  )
}

pub type CoverageSummary {
  CoverageSummary(
    by_module: List(ModuleCoverage),
  )
}

pub type RunnerOutcome(a) {
  RunnerOutcome(
    results: List(TestResult(a)),
    coverage: Option(CoverageSummary),
  )
}

pub fn run_tests(a, config: RunnerConfig, tests: List(TestCase(a))) -> RunnerOutcome(a)
```

### 4.2 Filtering and execution flow

1. Filter `tests` by `include_tags` / `exclude_tags` and `kind` (unit vs integration).
2. If `coverage_mode != NoCoverage`, start a coverage session and register modules/paths from `coverage_paths`.
3. For each `TestCase`, spawn a supervised sandbox:
   - `TestSupervisor` (one per test).
   - `TestWorker` process runs `TestCase.run`.
4. Wait for completion or timeout.
5. After all tests complete, if coverage is enabled, collect a `CoverageSummary` from the coverage subsystem.
6. Return a `RunnerOutcome` containing both `results` and optional `coverage`, in a deterministic order.

### 4.3 Sandboxed supervisor (high-level idea)

- Each test gets a supervisor tree:
  - Test-specific supervisor (`TestSupervisor`).
  - Child worker process (`TestWorker`) that runs the test body.
- Tests can spawn child processes under their sandbox using helpers exposed in `TestContext` (later):
  - These children are supervised and killed when the test finishes or times out.

**Example pseudo-flow for a single test:**

```text
Runner
  └─ spawn TestSupervisor
       └─ spawn TestWorker (runs TestCase.run)

TestWorker executes test:
  - builds TestContext
  - runs assertions
  - returns TestResult

Runner waits up to `timeout_ms`:
  - on success: collects TestResult
  - on timeout: kills TestSupervisor, returns a TimedOut TestResult
```

---

## 5. Unit Test DSL (`describe` / `it` / tags / hooks)

### 5.1 Example user test file

```gleam
import dream_test.{describe, it, tag, before_each}
import should

pub fn tests() {
  describe("User registration", [
    before_each(fn(ctx) {
      // setup code
      ctx
    }),

    it("creates a user with valid data", fn(ctx) {
      let user = register_user(valid_input())

      user.name
      |> should.equal("Alice")(ctx)
      |> should.or_fail_with("User name should be Alice")
    })
    |> tag("unit")
    |> tag("user"),

    it("rejects invalid email", fn(ctx) {
      let result = register_user(invalid_email_input())

      result.is_error
      |> should.equal(True)(ctx)
      |> should.or_fail_with("Invalid email should be rejected")
    })
    |> tag("unit")
  ])
}
```

### 5.2 How DSL compiles to `TestCase`s

`describe` and `it` build up a tree of test definitions which is later flattened to a list of `TestCase`s.

- `describe("User registration", tests)` contributes a prefix to `full_name` (e.g. `"User registration"`).
- `it("creates a user", fn(ctx) { ... })` becomes a `TestCase`:
  - `name = "creates a user"`
  - `full_name = ["User registration", "creates a user"]`
  - `kind = Unit`
  - `tags` accumulated from `tag` decorators.
- Hooks like `before_each` / `after_each` wrap the `run` function.

Conceptually:

```gleam
pub fn it(label: String, body: fn(TestContext(a)) -> TestContext(a)) -> TestDefinition(a)

pub fn describe(label: String, children: List(TestDefinition(a))) -> List(TestCase(a))
```

DSL users only see `describe`/`it`, but internally we:

1. Walk the description tree.
2. Build `TestCase`s with proper `full_name`, `location`, `tags`, `kind`.
3. Wrap `run` with hook logic.

---

## 6. Gherkin Integration

We support **real `.feature` files** using standard Gherkin syntax.

### 6.1 Example `.feature` file

```gherkin
Feature: Greeting
  @integration
  Scenario: User sees a personalized greeting
    Given the test server is started on port 3000
    When I request "/greet?name=Gleam"
    Then I see "Hello, Gleam" in the response body
```

### 6.2 Step definitions in Gleam

```gleam
import gherkin
import should

pub fn steps() {
  [
    gherkin.define_step(
      pattern: "^the test server is started on port (\\d+)$",
      step_type: gherkin.Given,
      run: fn(ctx, args) {
        let [port_str] = args
        let assert Ok(port) = int.parse(port_str)

        // start server, store port in some shared context
        start_test_server(port)

        ctx
      },
    ),

    gherkin.define_step(
      pattern: "^I request \"(.+)\"$",
      step_type: gherkin.When,
      run: fn(ctx, [path]) {
        let response = http_get("http://localhost:3000" <> path)
        // store response in some shared place
        set_last_response(response)
        ctx
      },
    ),

    gherkin.define_step(
      pattern: "^I see \"(.+)\" in the response body$",
      step_type: gherkin.Then,
      run: fn(ctx, [expected]) {
        let response = get_last_response()

        response.body
        |> should.equal(expected)(ctx)
        |> should.or_fail_with("Response body did not contain expected text")
      },
    ),
  ]
}
```

### 6.3 GherkinScenario representation

```gleam
pub type StepType {
  Given
  When
  Then
}

pub type GherkinStep {
  GherkinStep(
    text: String,
    step_type: StepType,   // And/But normalized to previous type
    location: Location,
  )
}

pub type GherkinScenario {
  GherkinScenario(
    feature_name: String,
    scenario_name: String,
    tags: List(Tag),
    steps: List(GherkinStep),
    location: Location,
  )
}
```

The Gherkin parser converts `.feature` files into `GherkinScenario` values. The Gherkin runner then creates a `TestCase` per scenario:

```gleam
let tc = TestCase(
  name: scenario.scenario_name,
  full_name: [scenario.feature_name, scenario.scenario_name],
  tags: scenario.tags ++ ["integration"],
  location: scenario.location,
  kind: GherkinScenario(scenario_id),
  run: fn() {
    // apply background + steps by matching each GherkinStep to a StepDefinition
  },
)
```

---

## 7. Reporters

Reporters observe events from the runner and render them for humans or machines, including coverage information when available.

### 7.1 Reporter interface (conceptual)

```gleam
pub type Reporter(a) {
  Reporter(
    on_start: fn(List(TestCase(a))) -> Nil,
    on_result: fn(TestResult(a)) -> Nil,
    on_finish: fn(List(TestResult(a)), Option(CoverageSummary)) -> Nil,
  )
}
```

### 7.2 Console reporter (simplified behavior)

- `on_start`:
  - Print number of tests and basic config.
- `on_result`:
  - Print a dot (`.`) for pass, `F` for fail, `S` for skipped, etc.
- `on_finish`:
  - Summarize counts and durations.
  - Print detailed failure information (names, messages, diffs).

Example output:

```text
Running 12 tests (unit: 10, integration: 2)

..F...S....

Failures:
  1) User registration / rejects invalid email
     Expected: is_error == True
     Actual:   False
     Message:  Invalid email should be rejected

Summary: 12 run, 1 failed, 1 skipped in 0.45s
```

---

## 8. CLI / Entrypoint

We provide a single entrypoint module to run tests.

### 8.1 Example CLI usage

```bash
# Run all tests
gleam run -m dream_test_runner/cli

# Only unit tests
gleam run -m dream_test_runner/cli --unit

# Only integration (Gherkin) tests
gleam run -m dream_test_runner/cli --integration

# With tags
gleam run -m dream_test_runner/cli --tag unit --tag fast

# JSON reporter for CI
gleam run -m dream_test_runner/cli --reporter json > results.json
```

### 8.2 CLI responsibilities

- Discover:
  - Unit tests (e.g. modules exposing `pub fn tests()` or following a naming convention).
  - Feature files (`test/features/**/*.feature`).
  - Step definition modules.
- Build a `RunnerConfig` from CLI flags, including coverage mode and paths.
- Instantiate a reporter.
- Invoke `run_tests` and pass `RunnerOutcome.results` and `RunnerOutcome.coverage` to the reporter.
- Exit with a non-zero exit code if any test failed or timed out (coverage does not affect exit code by default but can be configured later).

---

## 9. Putting It All Together (End-to-End Example)

1. User writes a unit test file:

   ```gleam
   import dream_test.{describe, it}
   import should

   pub fn tests() {
     describe("Math", [
       it("adds numbers", fn(ctx) {
         add(1, 2)
         |> should.equal(3)(ctx)
         |> should.or_fail_with("1 + 2 should equal 3")
       }),
     ])
   }
   ```

2. User writes a Gherkin `.feature` file and step definitions.

3. User runs:

   ```bash
   gleam run -m dream_test_runner/cli
   ```

4. CLI discovers:
   - Unit tests via `tests()` functions.
   - Integration tests via `.feature` files + step definitions.

5. Runner:
   - Builds `TestCase`s for unit and Gherkin scenarios.
   - Runs each in a sandboxed supervisor with timeouts.
   - Produces `List(TestResult)`.

6. Reporter prints a concise progress view and a detailed summary.

This architecture keeps responsibilities clear, supports rich features (tags, hooks, Gherkin, parallelism), and is largely self-hosting once the runner and `should` core are in place.