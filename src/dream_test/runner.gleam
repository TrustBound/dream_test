import gleam/list
import dream_test/assertions/context.{type TestContext, new, failures}
import dream_test/core/types.{type TestKind, type TestResult, type Location, TestResult, status_from_failures}

/// Core runner helpers.
///
/// This initial version only supports running single test functions that
/// produce a TestContext. Timing, hooks, and concurrency will be added later.

pub type SingleTestConfig(a) {
  SingleTestConfig(
    name: String,
    full_name: List(String),
    tags: List(String),
    kind: TestKind,
    location: Location,
    run: fn(TestContext(a)) -> TestContext(a),
  )
}

/// A concrete test case, wrapping a SingleTestConfig.
pub type TestCase(a) {
  TestCase(SingleTestConfig(a))
}

pub fn run_single_test(config: SingleTestConfig(a)) -> TestResult(a) {
  let initial_context = new()
  let final_context = config.run(initial_context)
  let failures = failures(final_context)
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

pub fn run_test_case(test_case: TestCase(a)) -> TestResult(a) {
  case test_case {
    TestCase(config) ->
      run_single_test(config)
  }
}

pub fn run_all(test_cases: List(TestCase(a))) -> List(TestResult(a)) {
  run_all_from_list(test_cases, [])
}

fn run_all_from_list(remaining: List(TestCase(a)),
  accumulated: List(TestResult(a)),
) -> List(TestResult(a)) {
  case remaining {
    [] ->
      list.reverse(accumulated)

    [head, ..tail] -> {
      let result = run_test_case(head)
      run_all_from_list(tail, [result, ..accumulated])
    }
  }
}
