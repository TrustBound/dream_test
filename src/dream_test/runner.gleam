//// Test runner for dream_test.
////
//// This module executes test cases and produces results. Tests run in isolated
//// BEAM processes by default, providing:
////
//// - **Crash isolation** - A panicking test doesn't crash the runner
//// - **Timeout protection** - Hanging tests are killed after a timeout
//// - **Parallel execution** - Tests run concurrently for speed
////
//// ## Basic Usage
////
//// ```gleam
//// import dream_test/unit.{describe, it, to_test_cases}
//// import dream_test/runner.{run_all}
//// import dream_test/reporter/bdd.{report}
//// import gleam/io
////
//// pub fn main() {
////   tests()
////   |> to_test_cases("my_test")
////   |> run_all()
////   |> report(io.print)
//// }
//// ```
////
//// ## Execution Modes
////
//// | Function               | Isolation | Parallel | Timeout | Use Case                    |
//// |------------------------|-----------|----------|---------|------------------------------|
//// | `run_all`              | ✓         | ✓ (4)    | 5s      | Default for most tests       |
//// | `run_all_with_config`  | ✓         | Custom   | Custom  | Custom concurrency/timeout   |
//// | `run_all_sequential`   | ✗         | ✗        | ✗       | Debugging, simple tests      |
////
//// ## Custom Configuration
////
//// ```gleam
//// import dream_test/runner.{run_all_with_config, RunnerConfig}
////
//// // High concurrency for fast tests
//// let fast_config = RunnerConfig(
////   max_concurrency: 16,
////   default_timeout_ms: 1000,
//// )
////
//// // Sequential with long timeout for integration tests  
//// let integration_config = RunnerConfig(
////   max_concurrency: 1,
////   default_timeout_ms: 30_000,
//// )
////
//// test_cases
//// |> run_all_with_config(fast_config)
//// |> report(io.print)
//// ```
////   tests()
////   |> to_test_cases("my_test")
////   |> run_all()
////   |> report(io.print)
//// }

import dream_test/parallel
import dream_test/types.{
  type SingleTestConfig, type Status, type TestCase, type TestResult,
  type TestSuite, AssertionFailed, AssertionOk, AssertionSkipped, Failed, Passed,
  SetupFailed, Skipped, TestCase, TestResult, TimedOut,
}
import gleam/list

/// Configuration for test execution.
///
/// Controls how many tests run concurrently and how long each test is allowed
/// to run before being killed.
///
/// ## Fields
///
/// - `max_concurrency` - Maximum number of tests running at once. Set to `1`
///   for sequential execution. Higher values speed up test suites on multi-core
///   machines but may cause issues if tests share resources.
///
/// - `default_timeout_ms` - How long (in milliseconds) a test can run before
///   being killed. Protects against infinite loops and hanging operations.
///
/// ## Examples
///
/// ```gleam
/// // Fast parallel execution
/// RunnerConfig(max_concurrency: 8, default_timeout_ms: 2000)
///
/// // Sequential execution for debugging
/// RunnerConfig(max_concurrency: 1, default_timeout_ms: 5000)
///
/// // Long timeout for integration tests
/// RunnerConfig(max_concurrency: 4, default_timeout_ms: 60_000)
/// ```
///
pub type RunnerConfig {
  RunnerConfig(
    /// Maximum number of tests to run concurrently.
    /// Set to 1 for sequential execution.
    max_concurrency: Int,
    /// Default timeout in milliseconds for each test.
    default_timeout_ms: Int,
  )
}

/// Default runner configuration.
///
/// Returns a configuration with:
/// - 4 concurrent tests
/// - 5 second timeout per test
///
/// This is suitable for most unit test suites.
///
/// ## Example
///
/// ```gleam
/// let config = default_config()
/// // RunnerConfig(max_concurrency: 4, default_timeout_ms: 5000)
/// ```
///
pub fn default_config() -> RunnerConfig {
  RunnerConfig(max_concurrency: 4, default_timeout_ms: 5000)
}

/// Configuration for sequential execution.
///
/// Returns a configuration with:
/// - 1 concurrent test (sequential)
/// - 5 second timeout per test
///
/// Use this when debugging test failures or when tests must not run in parallel.
///
/// ## Example
///
/// ```gleam
/// test_cases
/// |> run_all_with_config(sequential_config())
/// |> report(io.print)
/// ```
///
pub fn sequential_config() -> RunnerConfig {
  RunnerConfig(max_concurrency: 1, default_timeout_ms: 5000)
}

/// Run all tests with custom configuration.
///
/// Each test runs in an isolated BEAM process. If a test panics, it doesn't
/// affect other tests. If a test exceeds the timeout, it's killed and marked
/// as `TimedOut`.
///
/// Results are returned in the same order as the input tests, regardless of
/// which tests finish first.
///
/// ## Example
///
/// ```gleam
/// let config = RunnerConfig(max_concurrency: 8, default_timeout_ms: 10_000)
///
/// tests()
/// |> to_test_cases("my_test")
/// |> run_all_with_config(config)
/// |> report(io.print)
/// ```
///
/// ## Parameters
///
/// - `config` - Execution settings (concurrency, timeout)
/// - `test_cases` - List of test cases to run
///
/// ## Returns
///
/// List of `TestResult` in the same order as the input tests.
///
pub fn run_all_with_config(
  config: RunnerConfig,
  test_cases: List(TestCase),
) -> List(TestResult) {
  let parallel_config =
    parallel.ParallelConfig(
      max_concurrency: config.max_concurrency,
      default_timeout_ms: config.default_timeout_ms,
    )
  parallel.run_parallel(parallel_config, test_cases)
}

/// Run all tests with default configuration.
///
/// This is the recommended way to run tests. Uses `default_config()`:
/// - 4 concurrent tests
/// - 5 second timeout per test
/// - Full process isolation
///
/// ## Example
///
/// ```gleam
/// pub fn main() {
/// ```
///
pub fn run_all(test_cases: List(TestCase)) -> List(TestResult) {
  run_all_with_config(default_config(), test_cases)
}

// =============================================================================
// Suite Execution (with before_all/after_all support)
// =============================================================================

/// Run a test suite with custom configuration.
///
/// Use this when you need `before_all`/`after_all` hooks with custom
/// concurrency or timeout settings. For default settings, use `run_suite`.
///
/// ## Execution Flow
///
/// For each group in the suite:
///
/// ```text
/// ┌─────────────────────────────────────────────────────────────┐
/// │ 1. Run before_all hooks (sequentially)                      │
/// │    └─ If any fail → mark all tests as SetupFailed, skip to 5│
/// │                                                              │
/// │ 2. For each test:                                           │
/// │    ├─ Run before_each hooks (outer → inner)                 │
/// │    ├─ Run test body                                         │
/// │    └─ Run after_each hooks (inner → outer)                  │
/// │                                                              │
/// │ 3. Tests run in parallel (up to max_concurrency)            │
/// │                                                              │
/// │ 4. Process nested groups (recurse)                          │
/// │                                                              │
/// │ 5. Run after_all hooks (always, even on failure)            │
/// └─────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Parallelism
///
/// - Tests within a group run in parallel
/// - `before_all` and `after_all` are synchronization barriers
/// - Nested groups are processed after their parent's tests complete
///
/// ## Example
///
/// ```gleam
/// import dream_test/unit.{describe, it, before_all, after_all, to_test_suite}
/// import dream_test/runner.{run_suite_with_config, RunnerConfig}
/// import dream_test/reporter/bdd.{report}
/// import dream_test/types.{AssertionOk}
/// import gleam/io
///
/// pub fn main() {
///   // Custom config for integration tests
///   let config = RunnerConfig(
///     max_concurrency: 2,          // Limit parallelism for shared resources
///     default_timeout_ms: 30_000,  // 30s timeout for slow operations
///   )
///
///   integration_tests()
///   |> to_test_suite("integration_test")
///   |> run_suite_with_config(config)
///   |> report(io.print)
/// }
///
/// fn integration_tests() {
///   describe("Database", [
///     before_all(fn() { start_database(); AssertionOk }),
///     before_each(fn() { begin_transaction(); AssertionOk }),
///
///     it("creates users", fn() { ... }),
///     it("queries users", fn() { ... }),
///
///     after_each(fn() { rollback_transaction(); AssertionOk }),
///     after_all(fn() { stop_database(); AssertionOk }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `config` - Execution settings (concurrency, timeout)
/// - `suite` - The test suite from `to_test_suite`
///
/// ## Returns
///
/// List of `TestResult` for all tests in the suite.
///
pub fn run_suite_with_config(
  config: RunnerConfig,
  suite: TestSuite,
) -> List(TestResult) {
  let parallel_config =
    parallel.ParallelConfig(
      max_concurrency: config.max_concurrency,
      default_timeout_ms: config.default_timeout_ms,
    )
  parallel.run_suite_parallel(parallel_config, suite)
}

/// Run a test suite with default configuration.
///
/// This is the recommended way to run tests when you need `before_all`
/// or `after_all` hooks. It uses sensible defaults suitable for most
/// integration test suites.
///
/// ## Default Configuration
///
/// | Setting            | Value   | Meaning                              |
/// |--------------------|---------|--------------------------------------|
/// | `max_concurrency`  | 4       | Up to 4 tests run in parallel        |
/// | `default_timeout`  | 5000ms  | Each test has 5 seconds to complete  |
///
/// For custom settings, use `run_suite_with_config`.
///
/// ## When to Use `run_suite` vs `run_all`
///
/// ```gleam
/// // Use run_all when you DON'T need before_all/after_all
/// tests()
/// |> to_test_cases("my_test")
/// |> run_all()
///
/// // Use run_suite when you DO need before_all/after_all
/// tests()
/// |> to_test_suite("my_test")
/// |> run_suite()
/// ```
///
/// ## Example
///
/// ```gleam
/// import dream_test/unit.{describe, it, before_all, after_all, to_test_suite}
/// import dream_test/runner.{run_suite}
/// import dream_test/reporter/bdd.{report}
/// import dream_test/types.{AssertionOk}
/// import gleam/io
///
/// pub fn main() {
///   tests()
///   |> to_test_suite("my_integration_test")
///   |> run_suite()
///   |> report(io.print)
/// }
///
/// fn tests() {
///   describe("API client", [
///     before_all(fn() {
///       start_mock_server()
///       AssertionOk
///     }),
///
///     it("fetches data", fn() { ... }),
///     it("handles errors", fn() { ... }),
///
///     after_all(fn() {
///       stop_mock_server()
///       AssertionOk
///     }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `suite` - The test suite from `to_test_suite`
///
/// ## Returns
///
/// List of `TestResult` for all tests in the suite.
///
pub fn run_suite(suite: TestSuite) -> List(TestResult) {
  run_suite_with_config(default_config(), suite)
}

/// Run all tests sequentially without process isolation.
///
/// Tests run one at a time in the main process. No timeout protection.
/// Use this for:
/// - Debugging test failures
/// - When process isolation causes issues
/// - Very simple test suites
///
/// **Warning:** A crashing test will crash the entire test run.
///
/// ## Example
///
/// ```gleam
/// // For debugging a specific failure
/// test_cases
/// |> run_all_sequential()
/// |> report(io.print)
/// ```
///
pub fn run_all_sequential(test_cases: List(TestCase)) -> List(TestResult) {
  run_all_from_list(test_cases, [])
}

/// Run a single test directly without isolation.
///
/// Executes the test function and returns a `TestResult`. No process isolation
/// or timeout protection. Useful for debugging individual tests.
///
/// ## Example
///
/// ```gleam
/// let config = SingleTestConfig(
///   name: "my test",
///   full_name: ["suite", "my test"],
///   tags: [],
///   kind: Unit,
///   run: fn() { ... },
///   timeout_ms: None,
/// )
///
/// let result = run_single_test(config)
/// ```
///
pub fn run_single_test(config: SingleTestConfig) -> TestResult {
  let assertion_result = config.run()

  let #(status, failures) = case assertion_result {
    AssertionOk -> #(Passed, [])
    AssertionFailed(failure) -> #(Failed, [failure])
    AssertionSkipped -> #(Skipped, [])
  }

  TestResult(
    name: config.name,
    full_name: config.full_name,
    status: status,
    duration_ms: 0,
    tags: config.tags,
    failures: failures,
    kind: config.kind,
  )
}

/// Run a single test case directly without isolation.
///
/// Convenience wrapper around `run_single_test` that unwraps the `TestCase`.
///
pub fn run_test_case(test_case: TestCase) -> TestResult {
  case test_case {
    TestCase(config) -> run_single_test(config)
  }
}

fn run_all_from_list(
  remaining: List(TestCase),
  accumulated: List(TestResult),
) -> List(TestResult) {
  case remaining {
    [] -> list.reverse(accumulated)

    [head, ..tail] -> {
      let result = run_test_case(head)
      run_all_from_list(tail, [result, ..accumulated])
    }
  }
}

// =============================================================================
// Exit Code Handling
// =============================================================================

/// Check if any test results indicate failure.
///
/// Returns `True` if any test has status `Failed`, `TimedOut`, or `SetupFailed`.
/// Returns `False` if all tests passed, were skipped, or are pending.
///
/// ## Example
///
/// ```gleam
/// let results = run_all(test_cases)
/// case has_failures(results) {
///   True -> io.println("Some tests failed!")
///   False -> io.println("All tests passed!")
/// }
/// ```
///
pub fn has_failures(results: List(TestResult)) -> Bool {
  check_for_failures(results)
}

fn check_for_failures(results: List(TestResult)) -> Bool {
  case results {
    [] -> False
    [result, ..rest] -> check_result_for_failure(result.status, rest)
  }
}

fn check_result_for_failure(status: Status, rest: List(TestResult)) -> Bool {
  case status {
    Failed -> True
    TimedOut -> True
    SetupFailed -> True
    Passed -> check_for_failures(rest)
    _ -> check_for_failures(rest)
  }
}

/// Exit the process with an appropriate exit code based on test results.
///
/// Exits with code 1 if any test failed, timed out, or had setup failures.
/// Exits with code 0 if all tests passed, were skipped, or are pending.
///
/// **Important:** This function terminates the BEAM process. Code after this
/// call will not execute.
///
/// ## Usage
///
/// Call this after reporting results to ensure CI systems detect test failures:
///
/// ```gleam
/// pub fn main() {
///   let results =
///     tests()
///     |> to_test_cases("my_test")
///     |> run_all()
///
///   report(results, io.print)
///   exit_on_failure(results)
/// }
/// ```
///
/// ## Exit Codes
///
/// | Condition                          | Exit Code |
/// |------------------------------------|-----------|
/// | All tests passed/skipped/pending   | 0         |
/// | Any test failed/timed out/setup failed | 1     |
///
pub fn exit_on_failure(results: List(TestResult)) -> Nil {
  let code = case has_failures(results) {
    True -> 1
    False -> 0
  }
  halt(code)
}

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil
