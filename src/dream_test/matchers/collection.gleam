//// Collection matchers for dream_test.
////
//// These matchers work with `List(a)` values and are re-exported through
//// `dream_test/matchers`.
////
//// Use them to assert collection properties like length, emptiness, and
//// membership.
////
//// ## Example
////
//// ```gleam
//// [1, 2, 3]
//// |> should
//// |> have_length(3)
//// |> or_fail_with("expected list length 3")
//// ```

import dream_test/types.{
  type MatchResult, AssertionFailure, CollectionFailure, MatchFailed, MatchOk,
}
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string

/// Assert that a list contains a specific item.
///
/// Use this when you want to assert membership while preserving the original
/// list for further checks.
///
/// ## Example
///
/// ```gleam
/// [1, 2, 3]
/// |> should
/// |> contain(2)
/// |> or_fail_with("expected list to contain 2")
/// ```
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(List(a))` produced by `should` (or a previous matcher)
/// - `expected_item`: the item that must be present in the list
///
/// ## Returns
///
/// A `MatchResult(List(a))`:
/// - On success, preserves the list for further chaining.
/// - On failure, the chain becomes failed and later matchers are skipped.
///
pub fn contain(
  value_or_result value_or_result: MatchResult(List(a)),
  expected_item expected_item: a,
) -> MatchResult(List(a)) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual_list) -> check_contains(actual_list, expected_item)
  }
}

fn check_contains(
  actual_list: List(a),
  expected_item: a,
) -> MatchResult(List(a)) {
  case list.contains(actual_list, expected_item) {
    True -> MatchOk(actual_list)
    False -> {
      let payload =
        CollectionFailure(
          actual: string.inspect(actual_list),
          expected: string.inspect(expected_item),
          operation: "contain",
        )

      MatchFailed(AssertionFailure(
        operator: "contain",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that a list does not contain a specific item.
///
/// Use this when you want to assert absence while preserving the original list
/// for further checks.
///
/// ## Example
///
/// ```gleam
/// ["a", "b", "c"]
/// |> should
/// |> not_contain("d")
/// |> or_fail_with("expected list to not contain \"d\"")
/// ```
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(List(a))` produced by `should` (or a previous matcher)
/// - `unexpected_item`: the item that must *not* be present in the list
///
/// ## Returns
///
/// A `MatchResult(List(a))`:
/// - On success, preserves the list for further chaining.
/// - On failure, the chain becomes failed and later matchers are skipped.
///
pub fn not_contain(
  value_or_result value_or_result: MatchResult(List(a)),
  unexpected_item unexpected_item: a,
) -> MatchResult(List(a)) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual_list) -> check_not_contains(actual_list, unexpected_item)
  }
}

fn check_not_contains(
  actual_list: List(a),
  unexpected_item: a,
) -> MatchResult(List(a)) {
  case list.contains(actual_list, unexpected_item) {
    False -> MatchOk(actual_list)
    True -> {
      let payload =
        CollectionFailure(
          actual: string.inspect(actual_list),
          expected: "not " <> string.inspect(unexpected_item),
          operation: "not_contain",
        )

      MatchFailed(AssertionFailure(
        operator: "not_contain",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that a list has a specific length.
///
/// Use this when you need to assert exact list length while preserving the list
/// for further checks.
///
/// ## Example
///
/// ```gleam
/// [1, 2, 3]
/// |> should
/// |> have_length(3)
/// |> or_fail_with("expected list length 3")
/// ```
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(List(a))` produced by `should` (or a previous matcher)
/// - `expected_length`: the exact length the list must have
///
/// ## Returns
///
/// A `MatchResult(List(a))`:
/// - On success, preserves the list for further chaining.
/// - On failure, the chain becomes failed and later matchers are skipped.
///
pub fn have_length(
  value_or_result value_or_result: MatchResult(List(a)),
  expected_length expected_length: Int,
) -> MatchResult(List(a)) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual_list) -> check_length(actual_list, expected_length)
  }
}

fn check_length(
  actual_list: List(a),
  expected_length: Int,
) -> MatchResult(List(a)) {
  let actual_length = list.length(actual_list)

  case actual_length == expected_length {
    True -> MatchOk(actual_list)
    False -> {
      let payload =
        CollectionFailure(
          actual: "list with length " <> int.to_string(actual_length),
          expected: "list with length " <> int.to_string(expected_length),
          operation: "have_length",
        )

      MatchFailed(AssertionFailure(
        operator: "have_length",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that a list is empty.
///
/// Use this when you want to assert there are no values while preserving the
/// list for further checks.
///
/// ## Example
///
/// ```gleam
/// []
/// |> should
/// |> be_empty()
/// |> or_fail_with("expected empty list")
/// ```
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(List(a))` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(List(a))`:
/// - On success, preserves the list for further chaining.
/// - On failure, the chain becomes failed and later matchers are skipped.
///
pub fn be_empty(
  value_or_result value_or_result: MatchResult(List(a)),
) -> MatchResult(List(a)) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual_list) -> check_is_empty(actual_list)
  }
}

fn check_is_empty(actual_list: List(a)) -> MatchResult(List(a)) {
  case actual_list {
    [] -> MatchOk(actual_list)
    _ -> {
      let payload =
        CollectionFailure(
          actual: string.inspect(actual_list),
          expected: "[]",
          operation: "be_empty",
        )

      MatchFailed(AssertionFailure(
        operator: "be_empty",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}
