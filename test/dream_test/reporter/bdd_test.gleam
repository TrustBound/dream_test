import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporter/bdd.{format}
import dream_test/types.{
  AssertionFailure, EqualityFailure, Failed, Passed, TestResult, Unit,
}
import dream_test/unit.{describe, it}
import gleam/option.{Some}

pub fn tests() {
  describe("BDD Reporter", [
    describe("format", [
      it("renders a basic BDD-style report", fn() {
        // Arrange
        let passing =
          TestResult(
            name: "adds numbers",
            full_name: ["Math", "adds numbers"],
            status: Passed,
            duration_ms: 0,
            tags: [],
            failures: [],
            kind: Unit,
          )

        let failure =
          AssertionFailure(
            operator: "equal",
            message: "1 + 2 should equal 3",
            payload: Some(EqualityFailure(actual: "4", expected: "3")),
          )

        let failing =
          TestResult(
            name: "adds numbers incorrectly",
            full_name: ["Math", "adds numbers incorrectly"],
            status: Failed,
            duration_ms: 0,
            tags: [],
            failures: [failure],
            kind: Unit,
          )

        let results = [passing, failing]

        let expected =
          "Math\n"
          <> "  ✓ adds numbers\n"
          <> "  ✗ adds numbers incorrectly\n"
          <> "    equal\n"
          <> "      Message: 1 + 2 should equal 3\n"
          <> "      Expected: 3\n"
          <> "      Actual:   4\n"
          <> "\n"
          <> "Summary: 2 run, 1 failed, 1 passed in 0ms\n"

        // Act
        let result = format(results)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("bdd.format should render a basic BDD-style report")
      }),
    ]),
  ])
}
