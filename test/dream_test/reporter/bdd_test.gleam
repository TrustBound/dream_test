import dream_test/bootstrap/assertions
import gleam/option.{Some}
import dream_test/types.{type TestResult, TestResult, AssertionFailure, EqualityFailure, Location, Passed, Failed, Unit}
import dream_test/reporter/bdd.{format}

fn passing_result() -> TestResult {
  TestResult(
    name: "adds numbers",
    full_name: ["Math", "adds numbers"],
    status: Passed,
    duration_ms: 0,
    tags: [],
    failures: [],
    location: Location("math_test", "math_test.gleam", 0),
    kind: Unit,
  )
}

fn failing_result() -> TestResult {
  let failure = AssertionFailure(
    operator: "equal",
    message: "1 + 2 should equal 3",
    location: Location("math_test", "math_test.gleam", 0),
    payload: Some(EqualityFailure(
      actual: "4",
      expected: "3",
    )),
  )

  TestResult(
    name: "adds numbers incorrectly",
    full_name: ["Math", "adds numbers incorrectly"],
    status: Failed,
    duration_ms: 0,
    tags: [],
    failures: [failure],
    location: Location("math_test", "math_test.gleam", 0),
    kind: Unit,
  )
}

pub fn main() {
  let results: List(TestResult) = [
    passing_result(),
    failing_result(),
  ]

  let text = format(results)

  let expected =
    "Math\n"
    <> "  ✓ adds numbers\n"
    <> "  ✗ adds numbers incorrectly\n"
    <> "    equal\n"
    <> "      Message: 1 + 2 should equal 3\n"
    <> "      Expected: 3\n"
    <> "      Actual:   4\n"
    <> "\n"
    <> "Summary: 2 run, 1 failed, 1 passed\n"

  assertions.equal(expected, text, "bdd.format should render a basic BDD-style report")
}
