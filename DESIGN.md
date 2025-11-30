# Dream Test Framework Design

## Goals
- Provide a **Gleam-first** testing framework that supports:
  - Rich **unit tests** with names, metadata, tags, and good failure messages.
  - **Integration tests** and **BDD-style** tests using real Gherkin `.feature` files.
  - A clean **Gleam-native runner** (no Elixir/Mix setup required).
- Separate concerns:
  - **Runner core** (test discovery, execution, concurrency, isolation).
  - **Assertion libraries** (starting with a `should`-style API, but pluggable).
  - **Reporters** (console, JSON/JUnit, etc.).
  - **Gherkin / integration layer** (feature parsing, step matching, scenario execution).
- Leverage the **BEAM** for isolation:
  - Each test runs in its own supervised sandbox.
  - Easy parallelism for unit tests, safe sequential or opt-in parallelism for integration tests.
- Be self-contained and self-hosting:
  - No long-term dependency on `gleeunit`.
  - Bootstrap the framework using a minimal internal assertion core.
- Treat **coverage** as a first-class feature:
  - Runner-aware configuration for enabling/disabling coverage and selecting mode.
  - Coverage results returned alongside test results and exposed to reporters.

## High-Level Architecture

The system is structured in **layers**, each depending only on the layer(s) below it. The lowest layer uses only raw Gleam (`assert`, pattern matching). Higher layers implement the user-facing API and test framework behavior.

### Layer 0 – Raw Gleam Assertions
- Uses built-in Gleam `assert` and `let assert` only.
- Purpose:
  - Test the initial minimal assertion helper module (`core_assert`).
  - This is the only place where tests directly use raw `assert`.
- Example:
  - `assert some_condition as "message"`.

### Layer 1 – `core_assert`: Minimal Internal Assertions
- Very small, internal-only assertion helpers.
- No runner, no reporters, no tags.
- Responsibilities:
  - Provide simple functions like:
    - `core_assert.equal(expected, actual, message)`
    - `core_assert.is_true(cond, message)`
  - Wrap raw `assert` with clearer semantics and reusable messages.
- Used to test:
  - Core types and helpers in higher layers (e.g. status derivation, result shaping).
- Never rewired.
  - Always implemented in terms of Gleam built-ins.
  - Later layers are free to evolve without changing these tests.

### Layer 2 – Core Types & Low-Level Helpers
- Defines core data structures and helpers that do **not** depend on the runner yet.
- Examples:
  - `Location` (module, file, line).
  - `Status` (`Passed`, `Failed`, `Skipped`, `Pending`, `TimedOut`).
  - `AssertionFailure` (actual, expected, operator, message, location).
  - `TestResult` (name, status, duration, tags, failures, location, kind).
- Responsibilities:
  - Represent test and assertion outcomes in a structured way.
  - Provide helpers such as `derive_status(failures) -> Status`.
- Tested with:
  - `core_assert` functions (Layer 1).

### Layer 3 – Assertion Engine (`should` Core)
- First version of our real assertion system.
- Introduces:
  - `TestContext` – holds failures and other per-test data.
  - Core `should` functions (pipe-first style), e.g.:
    - `should.equal(expected)`
    - `should.or_fail_with(message)`
- Design principles:
  - **Pipe-first** API: value under test is on the left of the pipe.
    - `value |> should.equal(expected)(ctx) |> should.or_fail_with("message")`
  - Assertions produce/modify a `TestContext`, not raise directly.
  - Failures are **data** (`AssertionFailure`), not just strings.
- Tested with:
  - `core_assert` by inspecting `TestContext` and `AssertionFailure` values.

### Layer 4 – Runner Core
- Responsible for **executing** tests and collecting results.
- Concepts:
  - `TestCase` – a runnable test with:
    - `name`, `full_name` (hierarchical), `tags`, `location`, `kind` (unit/integration/Gherkin), and a `run` function.
  - `TestSuite` – a collection/tree of `TestCase`s.
- Responsibilities:
  - Execute `TestCase`s and produce `TestResult`s.
  - Enforce timeouts.
  - Apply filters (by tags, name, kind).
  - Manage concurrency.
- BEAM/OTP design:
  - Each `TestCase` runs in its own **sandboxed supervisor tree**:
    - Root: test supervisor.
    - Children: the test process and any processes it spawns via helper APIs.
  - On timeout or completion, the sandbox tree is cleaned up.
- Tested with:
  - `core_assert`, by calling into the runner and asserting on returned `TestResult`s.

### Layer 5 – Public Test DSL (Unit Testing)
- User-facing Gleam API for unit tests, built on top of the runner and assertion engine.
- Provides constructs like:
  - `describe("User registration", [ ... ])`
  - `it("creates a user", fn(ctx) { ... })`
  - Tagging and hooks:
    - `tag("unit")`, `tag("slow")`.
    - `before_all`, `after_all`, `before_each`, `after_each`.
- Responsibilities:
  - Expressive, readable test definitions in Gleam.
  - Attach metadata (names, tags, hooks) to `TestCase`s.
- Tested with:
  - Our own test framework (runner + `should`) once it is stable enough.
  - Early versions may still use `core_assert` to validate DSL -> `TestCase` translation.

### Layer 6 – Gherkin / Integration Layer
- Supports behavior-driven tests via real **Gherkin `.feature` files**.
- Responsibilities:
  - Parse `.feature` files (standard Gherkin syntax).
  - Represent features, scenarios, and steps as Gleam types.
  - Match steps to Gleam step definitions using patterns (regex or template syntax).
- Concepts:
  - `StepDefinition` – pattern + step type + handler function.
  - `GherkinScenario` – feature + scenario names, tags, steps, location.
  - Step types: `Given`, `When`, `Then` (with `And`/`But` normalized to one of these).
- Execution:
  - For each `GherkinScenario`, build a `TestCase`:
    - `full_name = [feature_name, scenario_name]`.
    - `kind = GherkinScenario(id)`.
    - `tags` from feature/scenario tags.
  - Scenario execution uses the same runner core and assertion engine.
- Integration tests can leverage Dream or other frameworks, but the Gherkin layer itself is generic.

### Layer 7 – Reporters, CLI, and Tooling
- **Reporters**:
  - Pretty console output (default).
  - Machine-readable formats (JSON, JUnit XML, etc.) for CI.
- **CLI / entrypoint**:
  - Unified command to run tests, e.g.:
    - `gleam run -m dream_test_runner/cli`.
  - Options:
    - `--unit`, `--integration`, `--features PATH`.
    - `--tag`, `--exclude-tag`.
    - `--reporter console|json|junit`.
    - `--timeout`, `--max-concurrency`.
- **Watch mode** (later):
  - File system watcher that re-runs affected tests on change.

## Coverage Strategy

We treat coverage as a first-class concern of the runner, not as an external script.

- The runner accepts configuration for coverage mode and which modules/paths to include.
- The runner returns both:
  - `List(TestResult)`
  - An optional `CoverageSummary` describing coverage by module (and later by line).
- Reporters can render coverage information for humans (console) and machines (JSON/LCOV).
- The underlying implementation (e.g. Erlang `:cover`, custom probes, or a hybrid) is hidden behind a small `coverage` module, so we can improve it without changing the public runner/CLI API.

Initially, coverage may be stubbed or minimal, but the architecture and types will be in place from the beginning.

## Bootstrapping Strategy

We explicitly avoid depending on `gleeunit`. Instead, we bootstrap our framework in **one direction** using our own code:

1. **Layer 0**: Use raw `assert` / `let assert` to test `core_assert`.
2. **Layer 1**: Use `core_assert` to test:
   - Core types (`Status`, `AssertionFailure`, `TestResult`).
   - Low-level helpers (e.g. status derivation, timing helpers).
3. **Layer 3**: Implement the `should` assertion engine and test it via `core_assert` by inspecting `TestContext`.
4. **Layer 4**: Implement the runner core and test it via `core_assert` by examining `TestResult`s and behavior (timeouts, status, etc.).
5. **Layer 5+**: Once the runner and basic assertions are stable, write tests for higher layers (DSL, Gherkin, reporters) **using the framework itself**:
   - `describe` / `it` / `should`.
   - Gherkin scenarios executed by our runner.

This gives us:

- Only a tiny bottom layer (`core_assert`) that relies on raw `assert`.
- No `gleeunit` dependency at any stage.
- A framework that is largely **self-hosting**, especially at the feature level users care about most.

## Design Decisions (Locked In)

- **Pipe-first assertions**:
  - Value under test on the left, assertion functions on the right.
  - Example: `value |> should.equal(expected)(ctx) |> should.or_fail_with("msg")`.
- **Real `.feature` files for Gherkin**:
  - Use standard Gherkin syntax and semantics.
  - `.feature` files live under a conventional directory (e.g. `test/features/`).
- **Sandboxed per-test supervisor**:
  - Each test case runs in its own supervised process tree.
  - Timeouts and cleanup are enforced at the supervisor level.
- **Pluggable components**:
  - Assertions, reporters, coverage collectors, and (in the future) assertion libraries beyond `should` are separate modules.
  - Integration with Dream or other frameworks is done via thin adapters on top of the generic core.

## Next Steps

1. Implement `src/core_assert.gleam` (Layer 1) using raw `assert`.
2. Define core types in `src/test_core.gleam` (Layer 2):
   - `Location`, `Status`, `AssertionFailure`, `TestResult`.
3. Add a simple bootstrap test module (e.g. `test/bootstrap/test_status_bootstrap.gleam`) that:
   - Uses `core_assert` to test status derivation and basic behavior.
4. Implement the initial `should` core and `TestContext` (Layer 3).
5. Implement a minimal runner that can execute a list of `TestCase`s synchronously (Layer 4).
6. Start layering the public DSL (`describe` / `it`) and integration/Gherkin support (Layers 5–6), and then reporters/CLI (Layer 7).
