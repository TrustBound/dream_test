import dream_test/assertions/should.{
  be_false, be_true, equal, fail_with, or_fail_with, should,
}
import dream_test/runner.{has_failures, run_single_test}
import dream_test/types.{
  type TestResult, AssertionFailed, AssertionFailure, AssertionOk,
  EqualityFailure, Failed, Passed, Pending, SetupFailed, SingleTestConfig,
  Skipped, TestResult, TimedOut, Unit,
}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}

pub fn tests() {
  describe("Runner", [
    describe("run_single_test", [
      it("produces Passed status for passing test", fn() {
        // Arrange
        let config =
          SingleTestConfig(
            name: "passing test",
            full_name: ["bootstrap", "runner_core"],
            tags: ["bootstrap", "runner"],
            kind: Unit,
            run: fn() { AssertionOk },
            timeout_ms: None,
            before_each_hooks: [],
            after_each_hooks: [],
          )
        let expected = Passed

        // Act
        let result = run_single_test(config)

        // Assert
        result.status
        |> should()
        |> equal(expected)
        |> or_fail_with("Passing test should have Passed status")
      }),

      it("produces empty failures list for passing test", fn() {
        // Arrange
        let config =
          SingleTestConfig(
            name: "passing test",
            full_name: ["bootstrap", "runner_core"],
            tags: ["bootstrap", "runner"],
            kind: Unit,
            run: fn() { AssertionOk },
            timeout_ms: None,
            before_each_hooks: [],
            after_each_hooks: [],
          )
        let expected = []

        // Act
        let result = run_single_test(config)

        // Assert
        result.failures
        |> should()
        |> equal(expected)
        |> or_fail_with("Passing test should have no failures")
      }),

      it("produces Failed status for failing test", fn() {
        // Arrange
        let failure =
          AssertionFailure(
            operator: "equal",
            message: "",
            payload: Some(EqualityFailure(actual: "1", expected: "2")),
          )
        let config =
          SingleTestConfig(
            name: "failing test",
            full_name: ["bootstrap", "runner_core"],
            tags: ["bootstrap", "runner"],
            kind: Unit,
            run: fn() { AssertionFailed(failure) },
            timeout_ms: None,
            before_each_hooks: [],
            after_each_hooks: [],
          )
        let expected = Failed

        // Act
        let result = run_single_test(config)

        // Assert
        result.status
        |> should()
        |> equal(expected)
        |> or_fail_with("Failing test should have Failed status")
      }),

      it("records at least one failure for failing test", fn() {
        // Arrange
        let failure =
          AssertionFailure(
            operator: "equal",
            message: "",
            payload: Some(EqualityFailure(actual: "1", expected: "2")),
          )
        let config =
          SingleTestConfig(
            name: "failing test",
            full_name: ["bootstrap", "runner_core"],
            tags: ["bootstrap", "runner"],
            kind: Unit,
            run: fn() { AssertionFailed(failure) },
            timeout_ms: None,
            before_each_hooks: [],
            after_each_hooks: [],
          )

        // Act
        let result = run_single_test(config)

        // Assert
        case result.failures {
          [] -> fail_with("Failing test should have at least one failure")
          [_, ..] -> AssertionOk
        }
      }),
    ]),
    describe("has_failures", [
      it("returns False for empty results", fn() {
        // Arrange
        let results = []

        // Act & Assert
        has_failures(results)
        |> should()
        |> be_false()
        |> or_fail_with("Empty results should have no failures")
      }),
      it("returns False when all tests passed", fn() {
        // Arrange
        let results = [
          make_result_with_status(Passed),
          make_result_with_status(Passed),
          make_result_with_status(Passed),
        ]

        // Act & Assert
        has_failures(results)
        |> should()
        |> be_false()
        |> or_fail_with("All passed results should have no failures")
      }),
      it("returns False when tests are skipped or pending", fn() {
        // Arrange
        let results = [
          make_result_with_status(Passed),
          make_result_with_status(Skipped),
          make_result_with_status(Pending),
        ]

        // Act & Assert
        has_failures(results)
        |> should()
        |> be_false()
        |> or_fail_with("Skipped and pending tests are not failures")
      }),
      it("returns True when any test failed", fn() {
        // Arrange
        let results = [
          make_result_with_status(Passed),
          make_result_with_status(Failed),
          make_result_with_status(Passed),
        ]

        // Act & Assert
        has_failures(results)
        |> should()
        |> be_true()
        |> or_fail_with("Should detect Failed status")
      }),
      it("returns True when any test timed out", fn() {
        // Arrange
        let results = [
          make_result_with_status(Passed),
          make_result_with_status(TimedOut),
        ]

        // Act & Assert
        has_failures(results)
        |> should()
        |> be_true()
        |> or_fail_with("Should detect TimedOut status")
      }),
      it("returns True when any test had setup failure", fn() {
        // Arrange
        let results = [
          make_result_with_status(Passed),
          make_result_with_status(SetupFailed),
        ]

        // Act & Assert
        has_failures(results)
        |> should()
        |> be_true()
        |> or_fail_with("Should detect SetupFailed status")
      }),
      it("returns True for first result being a failure", fn() {
        // Arrange
        let results = [
          make_result_with_status(Failed),
          make_result_with_status(Passed),
          make_result_with_status(Passed),
        ]

        // Act & Assert
        has_failures(results)
        |> should()
        |> be_true()
        |> or_fail_with("Should detect failure at start of list")
      }),
      it("returns True for last result being a failure", fn() {
        // Arrange
        let results = [
          make_result_with_status(Passed),
          make_result_with_status(Passed),
          make_result_with_status(Failed),
        ]

        // Act & Assert
        has_failures(results)
        |> should()
        |> be_true()
        |> or_fail_with("Should detect failure at end of list")
      }),
    ]),
  ])
}

// =============================================================================
// Test Helpers
// =============================================================================

fn make_result_with_status(status: types.Status) -> TestResult {
  TestResult(
    name: "test",
    full_name: ["test"],
    status: status,
    duration_ms: 0,
    tags: [],
    failures: [],
    kind: Unit,
  )
}
