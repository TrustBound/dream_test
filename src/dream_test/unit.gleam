import gleam/list
import dream_test/types.{Location, Unit, type AssertionResult}
import dream_test/runner.{type TestCase, TestCase, SingleTestConfig}

/// Unit test DSL types and helpers.
///
/// This layer is responsible for representing tests in a way that is
/// convenient to write, and then translating them into runner TestCase
/// values.

pub type UnitTest {
  ItTest(
    name: String,
    run: fn() -> AssertionResult,
  )
  DescribeGroup(
    name: String,
    children: List(UnitTest),
  )
}

/// Define a single test with a name and a body function.
///
/// From the test author's perspective this is typically invoked with an
/// anonymous `fn()` that uses `should` assertions.
pub fn it(name: String, run: fn() -> AssertionResult) -> UnitTest {
  ItTest(name, run)
}

/// Group tests under a common name.
pub fn describe(name: String, children: List(UnitTest)) -> UnitTest {
  DescribeGroup(name, children)
}

/// Translate a UnitTest tree into runner TestCase values.
///
/// `module_name` is used for the Location.module_ field; in the future we may
/// compute this automatically.
pub fn to_test_cases(module_name: String, root: UnitTest) -> List(TestCase) {
  to_test_cases_from_unit_test(module_name, [], root, [])
}

fn to_test_cases_from_unit_test(module_name: String,
  name_prefix: List(String),
  node: UnitTest,
  accumulated: List(TestCase),
) -> List(TestCase) {
  case node {
    ItTest(name, run) ->
      build_it_test_case(module_name, name_prefix, name, run, accumulated)

    DescribeGroup(name, children) -> {
      let new_prefix = list.append(name_prefix, [name])
      to_test_cases_from_list(module_name, new_prefix, children, accumulated)
    }
  }
}

fn build_it_test_case(module_name: String,
  name_prefix: List(String),
  name: String,
  run: fn() -> AssertionResult,
  accumulated: List(TestCase),
) -> List(TestCase) {
  let full_name = list.append(name_prefix, [name])
  let location = Location(module_name, "", 0)
  let config = SingleTestConfig(
    name: name,
    full_name: full_name,
    tags: [],
    kind: Unit,
    location: location,
    run: run,
  )
  let test_case = TestCase(config)
  [test_case, ..accumulated]
}

fn to_test_cases_from_list(module_name: String,
  name_prefix: List(String),
  remaining: List(UnitTest),
  accumulated: List(TestCase),
) -> List(TestCase) {
  case remaining {
    [] ->
      list.reverse(accumulated)

    [head, ..tail] -> {
      let updated = to_test_cases_from_unit_test(module_name, name_prefix, head, accumulated)
      to_test_cases_from_list(module_name, name_prefix, tail, updated)
    }
  }
}
