//// A function with the function-level docs that CONTRIBUTING.md asks for.

import dream_test/matchers
import dream_test/types.{type MatchResult}

import dream_test/unit.{describe, it}

/// Checks if the value equals the expected value.
///
/// Returns `MatchOk` if equal, `MatchFailed` with a diff otherwise.
/// Works with any type that supports equality comparison.
///
/// ## Example
///
/// ```gleam
/// 42
/// |> should
/// |> be_equal(42)
/// |> or_fail_with("Should be 42")
/// ```
pub fn be_equal(
  value_or_result value_or_result: MatchResult(a),
  expected expected: a,
) -> MatchResult(a) {
  matchers.be_equal(value_or_result, expected)
}

pub fn tests() {
  describe("CONTRIBUTING.md: a function with function docs", [
    it("runs the example of its docs", fn() {
      42
      |> matchers.should
      |> be_equal(42)
      |> matchers.or_fail_with("Should be 42")
    }),
  ])
}
