/// Tests for the sandbox module that provides process isolation.
///
/// These tests verify that:
/// - Tests run in isolated processes
/// - Timeouts work correctly
/// - Crashes are handled gracefully
import dream_test/assertions/should.{be_true, equal, or_fail_with, should}
import dream_test/sandbox.{
  SandboxCompleted, SandboxConfig, SandboxCrashed, SandboxTimedOut,
}
import dream_test/types.{AssertionFailed, AssertionFailure, AssertionOk}
import dream_test/unit.{describe, group, it}
import gleam/erlang/process
import gleam/option.{None}

pub fn tests() {
  describe("Sandbox", [
    group("run_isolated", [
      it("returns SandboxCompleted for a passing test", fn(_) {
        // Arrange
        let config = SandboxConfig(timeout_ms: 1000)
        let test_function = fn() { AssertionOk }

        // Act
        let result = sandbox.run_isolated(config, test_function)

        // Assert
        result
        |> should()
        |> equal(SandboxCompleted(AssertionOk))
        |> or_fail_with("Expected SandboxCompleted(AssertionOk)")
      }),

      it("returns SandboxCompleted with failure for a failing test", fn(_) {
        // Arrange
        let config = SandboxConfig(timeout_ms: 1000)
        let failure =
          AssertionFailure(
            operator: "equal",
            message: "test failure",
            payload: None,
          )
        let test_function = fn() { AssertionFailed(failure) }

        // Act
        let result = sandbox.run_isolated(config, test_function)

        // Assert
        result
        |> should()
        |> equal(SandboxCompleted(AssertionFailed(failure)))
        |> or_fail_with("Expected SandboxCompleted(AssertionFailed(failure))")
      }),

      it("returns SandboxTimedOut for a test that exceeds timeout", fn(_) {
        // Arrange
        let config = SandboxConfig(timeout_ms: 50)
        let test_function = fn() {
          // Sleep longer than timeout
          process.sleep(200)
          AssertionOk
        }

        // Act
        let result = sandbox.run_isolated(config, test_function)

        // Assert
        result
        |> should()
        |> equal(SandboxTimedOut)
        |> or_fail_with("Expected SandboxTimedOut")
      }),

      it("returns SandboxCrashed for a test that panics", fn(_) {
        // Arrange
        let config = SandboxConfig(timeout_ms: 1000)
        let test_function = fn() { panic as "intentional crash" }

        // Act
        let result = sandbox.run_isolated(config, test_function)

        // Assert
        let is_crashed = case result {
          SandboxCrashed(_) -> True
          _ -> False
        }

        is_crashed
        |> should()
        |> be_true()
        |> or_fail_with("Expected SandboxCrashed")
      }),

      it("isolates crashes from the parent process", fn(_) {
        // Arrange - if we get here, we weren't crashed by the child
        let config = SandboxConfig(timeout_ms: 1000)
        let test_function = fn() {
          panic as "this should not crash the test runner"
        }

        // Act
        let result = sandbox.run_isolated(config, test_function)

        // Assert - if we reach this point, isolation worked (and the child crashed)
        let is_crashed = case result {
          SandboxCrashed(_) -> True
          _ -> False
        }

        is_crashed
        |> should()
        |> be_true()
        |> or_fail_with(
          "Expected child crash to be isolated and reported as SandboxCrashed",
        )
      }),
    ]),
  ])
}
