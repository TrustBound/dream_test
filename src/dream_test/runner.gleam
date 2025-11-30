import gleam/list
import dream_test/types.{type TestKind, type TestResult, type Location, type AssertionResult, AssertionOk, AssertionFailed, TestResult, status_from_failures}

/// Core runner helpers.
///
/// This initial version only supports running single test functions that
/// return an AssertionResult. Timing, hooks, and concurrency will be added later.

pub type SingleTestConfig {
  SingleTestConfig(
    name: String,
    full_name: List(String),
    tags: List(String),
    kind: TestKind,
    location: Location,
    run: fn() -> AssertionResult,
  )
}

/// A concrete test case, wrapping a SingleTestConfig.
pub type TestCase {
  TestCase(SingleTestConfig)
}

pub fn run_single_test(config: SingleTestConfig) -> TestResult {
  let assertion_result = config.run()

  let failures =
    case assertion_result {
      AssertionOk -> []
      AssertionFailed(failure) -> [failure]
    }

  let status = status_from_failures(failures)

  TestResult(
    name: config.name,
    full_name: config.full_name,
    status: status,
    duration_ms: 0,
    tags: config.tags,
    failures: failures,
    location: config.location,
    kind: config.kind,
  )
}

pub fn run_test_case(test_case: TestCase) -> TestResult {
  case test_case {
    TestCase(config) ->
      run_single_test(config)
  }
}

pub fn run_all(test_cases: List(TestCase)) -> List(TestResult) {
  run_all_from_list(test_cases, [])
}

fn run_all_from_list(remaining: List(TestCase),
  accumulated: List(TestResult),
) -> List(TestResult) {
  case remaining {
    [] ->
      list.reverse(accumulated)

    [head, ..tail] -> {
      let result = run_test_case(head)
      run_all_from_list(tail, [result, ..accumulated])
    }
  }
}
