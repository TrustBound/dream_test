import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type FailurePayload, EqualityFailure, StepFailure}
import dream_test/unit.{describe, it}
import gleam/option.{type Option, None, Some}

/// The expected value of a failure, also of a failure in a Gherkin step.
pub fn expected_value(payload: Option(FailurePayload)) -> Option(String) {
  case payload {
    Some(EqualityFailure(expected:, ..)) -> Some(expected)
    Some(StepFailure(cause:, ..)) -> expected_value(cause)
    _ -> None
  }
}

pub fn tests() -> TestSuite {
  describe("FailurePayload", [
    it("has the variant StepFailure, with the payload of the step inside", fn() {
      // Arrange
      let payload =
        StepFailure(
          keyword: "Then",
          text: "the total is 5",
          file: None,
          line: Some(4),
          cause: Some(EqualityFailure(actual: "4", expected: "5")),
        )

      // Act
      let expected = expected_value(Some(payload))

      // Assert
      expected
      |> should
      |> be_equal(Some("5"))
      |> or_fail_with("expected the expected value of the step's failure")
    }),
  ])
}
