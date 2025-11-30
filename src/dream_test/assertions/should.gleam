import gleam/string
import gleam/option.{Some}
import dream_test/types.{type AssertionResult, EqualityFailure, AssertionFailure, AssertionOk, AssertionFailed, Location}

/// Pipe-first assertion helpers.
///
/// These functions operate on plain values and return an AssertionResult,
/// which the runner converts into structured failures.

/// Assert that `actual` equals `expected`, returning an AssertionResult.
///
/// Intended usage with pipes:
///   value |> should.equal(expected)
pub fn equal(actual: a, expected: a) -> AssertionResult {
  case actual == expected {
    True ->
      AssertionOk

    False -> {
      let payload = EqualityFailure(
        actual: inspect_value(actual),
        expected: inspect_value(expected),
      )

      AssertionFailed(
        AssertionFailure(
          operator: "equal",
          message: "",
          // For now we use a placeholder Location; runners may wrap
          // should.equal in a location-aware helper later.
          location: Location("unknown", "unknown", 0),
          payload: Some(payload),
        ),
      )
    }
  }
}

/// Override the message on a failed assertion.
/// If the result is already Ok, it is returned unchanged.
///
/// Intended usage with pipes:
///   value |> should.equal(expected) |> should.or_fail_with("message")
pub fn or_fail_with(result: AssertionResult, message: String) -> AssertionResult {
  case result {
    AssertionOk ->
      AssertionOk

    AssertionFailed(failure) ->
      AssertionFailed(AssertionFailure(..failure, message: message))
  }
}

fn inspect_value(value: a) -> String {
  // For now we rely on Gleam's built-in debug representation via string.inspect.
  // This can be refined later for prettier diffs.
  string.inspect(value)
}
