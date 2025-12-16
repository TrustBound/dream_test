import dream_test/assertions/should.{contain_string, or_fail_with, should}
import dream_test/reporter/json.{format}
import dream_test/types.{
  AssertionFailure, EqualityFailure, Failed, GherkinScenario, Passed, Skipped,
  TestResult, Unit,
}
import dream_test/unit.{describe, it}
import fixtures/test_results.{make_test, make_test_with_duration}
import gleam/option.{Some}

pub fn tests() {
  describe("JSON Reporter", [
    it("includes schema version", fn(_) {
      // Arrange
      let results = []

      // Act
      let result = format(results)

      // Assert
      result
      |> should()
      |> contain_string("\"version\":\"1.0\"")
      |> or_fail_with("Should include schema version")
    }),
    it("includes system info", fn(_) {
      // Arrange
      let results = []

      // Act
      let result = format(results)

      // Assert
      result
      |> should()
      |> contain_string("\"system\":{")
      |> or_fail_with("Should include system info object")
    }),
    it("includes summary with counts", fn(_) {
      // Arrange
      let results = [
        make_test("test1", Passed),
        make_test("test2", Failed),
        make_test("test3", Skipped),
      ]

      // Act
      let result = format(results)

      // Assert
      result
      |> should()
      |> contain_string("\"total\":3")
      |> or_fail_with("Should include correct total count")
    }),
    it("sums test durations", fn(_) {
      // Arrange
      let results = [
        make_test_with_duration("test1", Passed, 100),
        make_test_with_duration("test2", Passed, 200),
      ]

      // Act
      let result = format(results)

      // Assert
      result
      |> should()
      |> contain_string("\"duration_ms\":300")
      |> or_fail_with("Should sum durations")
    }),
    it("includes test name and full path", fn(_) {
      // Arrange
      let test_result =
        TestResult(
          name: "adds",
          full_name: ["Calculator", "add", "adds"],
          status: Passed,
          duration_ms: 0,
          tags: [],
          failures: [],
          kind: Unit,
        )

      // Act
      let result = format([test_result])

      // Assert
      result
      |> should()
      |> contain_string("\"full_name\":[\"Calculator\",\"add\",\"adds\"]")
      |> or_fail_with("Should include full name path")
    }),
    it("serializes status as lowercase string", fn(_) {
      // Arrange
      let results = [make_test("test", Failed)]

      // Act
      let result = format(results)

      // Assert
      result
      |> should()
      |> contain_string("\"status\":\"failed\"")
      |> or_fail_with("Should serialize status as lowercase string")
    }),
    it("includes gherkin scenario id in kind", fn(_) {
      // Arrange
      let test_result =
        TestResult(
          name: "Adding items",
          full_name: ["Cart", "Adding items"],
          status: Passed,
          duration_ms: 0,
          tags: [],
          failures: [],
          kind: GherkinScenario("cart_1"),
        )

      // Act
      let result = format([test_result])

      // Assert
      result
      |> should()
      |> contain_string("\"kind\":\"gherkin:cart_1\"")
      |> or_fail_with("Should include gherkin kind with scenario id")
    }),
    it("includes failure details with expected and actual", fn(_) {
      // Arrange
      let failure =
        AssertionFailure(
          operator: "equal",
          message: "mismatch",
          payload: Some(EqualityFailure(actual: "42", expected: "24")),
        )
      let test_result =
        TestResult(
          name: "test",
          full_name: ["test"],
          status: Failed,
          duration_ms: 0,
          tags: [],
          failures: [failure],
          kind: Unit,
        )

      // Act
      let result = format([test_result])

      // Assert
      result
      |> should()
      |> contain_string("\"expected\":\"24\"")
      |> or_fail_with("Should include expected value in failure")
    }),
  ])
}
