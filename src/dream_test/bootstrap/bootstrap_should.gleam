import dream_test/bootstrap/core_assert
import dream_test/assertions/context as context
import dream_test/assertions/should.{or_fail_with}

/// Bootstrap checks for the minimal should assertion helpers.
///
/// Uses core_assert to verify that `equal` populates failures correctly
/// and that `or_fail_with` overrides the failure message.
pub fn main() {
  // equal with matching values leaves failures empty
  let initial_context = context.new()
  let context_after_equal =
    3
    |> should.equal(initial_context, 3)

  let failures_after_equal = context.failures(context_after_equal)
  core_assert.equal([], failures_after_equal, "equal should not record a failure for equal values")

  // equal with non-matching values records a failure
  let context_with_failure =
    3
    |> should.equal(initial_context, 4)

  let failures_after_failure = context.failures(context_with_failure)
  core_assert.is_true(
    failures_after_failure != [],
    "equal should record a failure for non-matching values",
  )

  // or_fail_with overrides the last failure's message
  let context_with_custom_message =
    3
    |> should.equal(initial_context, 4)
    |> or_fail_with("Custom failure message")

  let failures_after_custom_message = context.failures(context_with_custom_message)

  case failures_after_custom_message {
    [failure, ..] ->
      core_assert.equal(
        "Custom failure message",
        failure.message,
        "or_fail_with should override the failure message",
      )

    [] ->
      core_assert.is_true(False, "or_fail_with bootstrap expected at least one failure")
  }
}
