import dream_test/bootstrap/assertions
import dream_test/types.{type AssertionResult, AssertionOk, AssertionFailed}
import dream_test/assertions/should.{or_fail_with}

/// Bootstrap checks for the minimal should assertion helpers.
///
/// Uses core_assert to verify that `equal` classifies equal/unequal values
/// correctly, and that `or_fail_with` overrides the failure message.
pub fn main() {
  // equal: equal values -> AssertionOk
  case 3 |> should.equal(3) {
    AssertionOk -> Nil
    AssertionFailed(_) ->
      assertions.is_true(False, "equal should not fail for equal values")
  }

  // equal: unequal values -> AssertionFailed
  case 3 |> should.equal(4) {
    AssertionFailed(_) -> Nil
    AssertionOk ->
      assertions.is_true(False, "equal should fail for non-matching values")
  }

  // or_fail_with: overrides the failure message when there is a failure
  let custom_result: AssertionResult =
    3
    |> should.equal(4)
    |> or_fail_with("Custom failure message")

  case custom_result {
    AssertionFailed(failure) ->
      assertions.equal(
        "Custom failure message",
        failure.message,
        "or_fail_with should override the failure message",
      )

    AssertionOk ->
      assertions.is_true(False, "Expected a failed assertion from custom_result")
  }
}
