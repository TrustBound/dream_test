import dream_test/assertions/should.{equal, fail_with, or_fail_with, should}
import dream_test/types.{
  AssertionFailed, AssertionOk, AssertionSkipped, MatchFailed, MatchOk,
}
import dream_test/unit.{describe, group, it}

pub fn tests() {
  describe("Should", [
    group("equal", [
      it("returns MatchOk for equal values", fn(_) {
        // Arrange
        let value = 3
        let expected_value = 3

        // Act
        let result = value |> should() |> equal(expected_value)

        // Assert
        case result {
          MatchOk(_) -> Ok(AssertionOk)
          MatchFailed(_) ->
            Ok(fail_with("equal should not fail for equal values"))
        }
      }),
      it("returns MatchFailed for unequal values", fn(_) {
        // Arrange
        let value = 3
        let expected_value = 4

        // Act
        let result = value |> should() |> equal(expected_value)

        // Assert
        case result {
          MatchFailed(_) -> Ok(AssertionOk)
          MatchOk(_) ->
            Ok(fail_with("equal should fail for non-matching values"))
        }
      }),
    ]),
    group("or_fail_with", [
      it("overrides the failure message", fn(_) {
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
          Ok(AssertionFailed(failure)) ->
            failure.message
            |> should()
            |> equal(custom_message)
            |> or_fail_with("or_fail_with should override the failure message")

          Ok(AssertionOk) | Ok(AssertionSkipped) ->
            Ok(fail_with("Expected a failed assertion"))

          Error(_) -> Ok(fail_with("Expected a failed assertion"))
        }
      }),
    ]),
  ])
}
