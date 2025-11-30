import gleam/list
import dream_test/assertions/context.{type TestContext}
import dream_test/core/types.{Location, Unit}
import dream_test/runner.{type TestCase, TestCase, SingleTestConfig}

/// Unit test DSL types and helpers.
///
/// This layer is responsible for representing tests in a way that is
/// convenient to write, and then translating them into runner TestCase
/// values.

pub type UnitTest(a) {
  ItTest(
    name: String,
    run: fn(TestContext(a)) -> TestContext(a),
  )
  DescribeGroup(
    name: String,
    children: List(UnitTest(a)),
  )
}

/// Define a single test with a name and a body function.
pub fn it(name: String, run: fn(TestContext(a)) -> TestContext(a)) -> UnitTest(a) {
  ItTest(name, run)
}

/// Group tests under a common name.
pub fn describe(name: String, children: List(UnitTest(a))) -> UnitTest(a) {
  DescribeGroup(name, children)
}

/// Translate a UnitTest tree into runner TestCase values.
///
/// `module_name` is used for the Location.module_ field; in the future we may
/// compute this automatically.
pub fn to_test_cases(module_name: String, root: UnitTest(a)) -> List(TestCase(a)) {
  to_test_cases_from_unit_test(module_name, [], root, [])
}

fn to_test_cases_from_unit_test(module_name: String,
  name_prefix: List(String),
  node: UnitTest(a),
  accumulated: List(TestCase(a)),
) -> List(TestCase(a)) {
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
  run: fn(TestContext(a)) -> TestContext(a),
  accumulated: List(TestCase(a)),
) -> List(TestCase(a)) {
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
  remaining: List(UnitTest(a)),
  accumulated: List(TestCase(a)),
) -> List(TestCase(a)) {
  case remaining {
    [] ->
      list.reverse(accumulated)

    [head, ..tail] -> {
      let updated = to_test_cases_from_unit_test(module_name, name_prefix, head, accumulated)
      to_test_cases_from_list(module_name, name_prefix, tail, updated)
    }
  }
}
