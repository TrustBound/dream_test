import dream_test/assertions/should.{equal, fail_with, or_fail_with, should}
import dream_test/runner.{run_all}
import dream_test/types.{AssertionOk, Skipped}
import dream_test/unit.{type UnitTest, describe, it, skip, to_test_cases}

pub fn tests() {
  describe("Unit DSL", [
    describe("to_test_cases", [
      it("creates first test case with correct name", fn() {
        // Arrange
        let test_tree: UnitTest =
          describe("Math", [
            it("adds numbers", fn() { AssertionOk }),
            it("subtracts numbers", fn() { AssertionOk }),
          ])
        let expected = "adds numbers"

        // Act
        let test_cases = to_test_cases("test_module", test_tree)
        let results = run_all(test_cases)

        // Assert
        case results {
          [first, ..] -> {
            first.name
            |> should()
            |> equal(expected)
            |> or_fail_with("First test name should match it label")
          }
          _ -> fail_with("Expected at least one test case")
        }
      }),

      it("creates second test case with correct name", fn() {
        // Arrange
        let test_tree: UnitTest =
          describe("Math", [
            it("adds numbers", fn() { AssertionOk }),
            it("subtracts numbers", fn() { AssertionOk }),
          ])
        let expected = "subtracts numbers"

        // Act
        let test_cases = to_test_cases("test_module", test_tree)
        let results = run_all(test_cases)

        // Assert
        case results {
          [_, second] -> {
            second.name
            |> should()
            |> equal(expected)
            |> or_fail_with("Second test name should match it label")
          }
          _ -> fail_with("Expected at least two test cases")
        }
      }),

      it("creates first test case with correct full_name path", fn() {
        // Arrange
        let test_tree: UnitTest =
          describe("Math", [
            it("adds numbers", fn() { AssertionOk }),
            it("subtracts numbers", fn() { AssertionOk }),
          ])
        let expected = ["Math", "adds numbers"]

        // Act
        let test_cases = to_test_cases("test_module", test_tree)
        let results = run_all(test_cases)

        // Assert
        case results {
          [first, ..] -> {
            first.full_name
            |> should()
            |> equal(expected)
            |> or_fail_with("First full_name should include describe and it")
          }
          _ -> fail_with("Expected at least one test case")
        }
      }),

      it("creates second test case with correct full_name path", fn() {
        // Arrange
        let test_tree: UnitTest =
          describe("Math", [
            it("adds numbers", fn() { AssertionOk }),
            it("subtracts numbers", fn() { AssertionOk }),
          ])
        let expected = ["Math", "subtracts numbers"]

        // Act
        let test_cases = to_test_cases("test_module", test_tree)
        let results = run_all(test_cases)

        // Assert
        case results {
          [_, second] -> {
            second.full_name
            |> should()
            |> equal(expected)
            |> or_fail_with("Second full_name should include describe and it")
          }
          _ -> fail_with("Expected at least two test cases")
        }
      }),
    ]),
    describe("skip", [
      it("produces Skipped status", fn() {
        // Arrange
        let test_tree: UnitTest =
          describe("Feature", [skip("not ready yet", fn() { AssertionOk })])

        // Act
        let test_cases = to_test_cases("test_module", test_tree)
        let results = run_all(test_cases)

        // Assert
        case results {
          [first] -> {
            first.status
            |> should()
            |> equal(Skipped)
            |> or_fail_with("skip should produce Skipped status")
          }
          _ -> fail_with("Expected exactly one test case")
        }
      }),
      it("preserves the test name", fn() {
        // Arrange
        let test_tree: UnitTest =
          describe("Feature", [skip("work in progress", fn() { AssertionOk })])

        // Act
        let test_cases = to_test_cases("test_module", test_tree)
        let results = run_all(test_cases)

        // Assert
        case results {
          [first] -> {
            first.name
            |> should()
            |> equal("work in progress")
            |> or_fail_with("skip should preserve the test name")
          }
          _ -> fail_with("Expected exactly one test case")
        }
      }),
    ]),
  ])
}
