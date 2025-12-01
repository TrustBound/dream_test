import dream_test/assertions/should.{equal, fail_with, or_fail_with, should}
import dream_test/types.{
  AssertionFailed, AssertionOk, AssertionSkipped, MatchFailed, MatchOk,
}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Should", [
    describe("equal", [
      it("returns MatchOk for equal values", fn() {
        // Arrange
        let value = 3
        let expected_value = 3

        // Act
        let result = value |> should() |> equal(expected_value)

        // Assert
        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) -> fail_with("equal should not fail for equal values")
        }
      }),
      it("returns MatchFailed for unequal values", fn() {
        // Arrange
        let value = 3
        let expected_value = 4

        // Act
        let result = value |> should() |> equal(expected_value)

        // Assert
        case result {
          MatchFailed(_) -> AssertionOk
          MatchOk(_) -> fail_with("equal should fail for non-matching values")
        }
      }),
    ]),
    describe("or_fail_with", [
      it("overrides the failure message", fn() {
        // Arrange
        let value = 3
        let expected_value = 4
        let custom_message = "Custom failure message"

        // Act
        let result =
          value
          |> should()
          |> equal(expected_value)
          |> or_fail_with(custom_message)

        // Assert
        case result {
          AssertionFailed(failure) -> {
            failure.message
            |> should()
            |> equal(custom_message)
            |> or_fail_with("or_fail_with should override the failure message")
          }
          AssertionOk | AssertionSkipped ->
            fail_with("Expected a failed assertion")
        }
      }),
    ]),
  ])
}
