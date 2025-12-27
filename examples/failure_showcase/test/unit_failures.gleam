//// Unit test failures for the failure showcase example.

import dream_test/matchers.{
  be_empty, be_equal, be_error, be_greater_than, be_less_than, be_none, be_ok,
  be_some, be_true, contain, contain_string, end_with, have_length, match_regex,
  match_snapshot, or_fail_with, should, start_with, succeed,
}
import dream_test/types.{
  type AssertionResult, type MatchResult, AssertionFailure, CustomMatcherFailure,
  MatchFailed, MatchOk,
}
import dream_test/unit.{after_each, before_all, before_each, describe, group, it}
import gleam/erlang/process
import gleam/int
import gleam/option.{None, Some}

pub fn tests() {
  describe("Failure Showcase (unit)", [
    it("assertion payload: equality mismatch", fn() {
      1
      |> should
      |> be_equal(2)
      |> or_fail_with("intentional equality failure: 1 should equal 2")
    }),

    it("assertion payload: boolean mismatch", fn() {
      False
      |> should
      |> be_true()
      |> or_fail_with("intentional boolean failure: expected True")
    }),

    it("explicit Error(...) from test body", fn() {
      Error("intentional Error(...) from test body")
    }),

    it("sandbox crash (panic)", fn() {
      panic as "intentional crash for failure showcase"
    }),

    it("timeout (default timeout is set low in the runner)", fn() {
      process.sleep(50)
      Ok(succeed())
    }),

    // =========================================================================
    // FailurePayload coverage (matcher failures)
    // =========================================================================
    it("assertion payload: option mismatch (be_some)", fail_option_be_some),
    it("assertion payload: option mismatch (be_none)", fail_option_be_none),
    it("assertion payload: result mismatch (be_ok)", fail_result_be_ok),
    it("assertion payload: result mismatch (be_error)", fail_result_be_error),
    it(
      "assertion payload: collection mismatch (contain)",
      fail_collection_contain,
    ),
    it(
      "assertion payload: collection mismatch (have_length)",
      fail_collection_have_length,
    ),
    it(
      "assertion payload: collection mismatch (be_empty)",
      fail_collection_be_empty,
    ),
    it(
      "assertion payload: comparison mismatch (be_greater_than)",
      fail_comparison_greater_than,
    ),
    it(
      "assertion payload: comparison mismatch (be_less_than)",
      fail_comparison_less_than,
    ),
    it(
      "assertion payload: string mismatch (start_with)",
      fail_string_start_with,
    ),
    it("assertion payload: string mismatch (end_with)", fail_string_end_with),
    it(
      "assertion payload: string mismatch (contain_string)",
      fail_string_contain_string,
    ),
    it(
      "assertion payload: string mismatch (match_regex)",
      fail_string_match_regex,
    ),
    it("assertion payload: snapshot mismatch", fail_snapshot_mismatch),
    it("assertion payload: custom matcher failure", fail_custom_matcher),

    group("hook failure: before_all", [
      before_all(fn() { Error("intentional before_all failure") }),
      it("test 1 (will not run, should be marked failed)", fn() {
        Ok(succeed())
      }),
      it("test 2 (will not run, should be marked failed)", fn() {
        Ok(succeed())
      }),
    ]),

    group("hook failure: before_each", [
      before_each(fn() { Error("intentional before_each failure") }),
      it("will not run, should be marked failed", fn() { Ok(succeed()) }),
    ]),

    group("hook failure: after_each", [
      after_each(fn() { Error("intentional after_each failure") }),
      it("runs but fails during teardown", fn() { Ok(succeed()) }),
    ]),
  ])
}

fn fail_option_be_some() -> Result(AssertionResult, String) {
  None
  |> should
  |> be_some()
  |> or_fail_with("intentional OptionFailure: expected Some(_)")
}

fn fail_option_be_none() -> Result(AssertionResult, String) {
  Some(1)
  |> should
  |> be_none()
  |> or_fail_with("intentional OptionFailure: expected None")
}

fn fail_result_be_ok() -> Result(AssertionResult, String) {
  Error("nope")
  |> should
  |> be_ok()
  |> or_fail_with("intentional ResultFailure: expected Ok(_)")
}

fn fail_result_be_error() -> Result(AssertionResult, String) {
  Ok(1)
  |> should
  |> be_error()
  |> or_fail_with("intentional ResultFailure: expected Error(_)")
}

fn fail_collection_contain() -> Result(AssertionResult, String) {
  [1, 2]
  |> should
  |> contain(3)
  |> or_fail_with("intentional CollectionFailure: expected list to contain 3")
}

fn fail_collection_have_length() -> Result(AssertionResult, String) {
  [1, 2, 3]
  |> should
  |> have_length(2)
  |> or_fail_with("intentional CollectionFailure: expected length 2")
}

fn fail_collection_be_empty() -> Result(AssertionResult, String) {
  [1]
  |> should
  |> be_empty()
  |> or_fail_with("intentional CollectionFailure: expected empty list")
}

fn fail_comparison_greater_than() -> Result(AssertionResult, String) {
  1
  |> should
  |> be_greater_than(2)
  |> or_fail_with("intentional ComparisonFailure: expected > 2")
}

fn fail_comparison_less_than() -> Result(AssertionResult, String) {
  10
  |> should
  |> be_less_than(3)
  |> or_fail_with("intentional ComparisonFailure: expected < 3")
}

fn fail_string_start_with() -> Result(AssertionResult, String) {
  "hello"
  |> should
  |> start_with("world")
  |> or_fail_with("intentional StringMatchFailure: expected prefix world")
}

fn fail_string_end_with() -> Result(AssertionResult, String) {
  "hello"
  |> should
  |> end_with(".gleam")
  |> or_fail_with("intentional StringMatchFailure: expected suffix .gleam")
}

fn fail_string_contain_string() -> Result(AssertionResult, String) {
  "hello"
  |> should
  |> contain_string("world")
  |> or_fail_with("intentional StringMatchFailure: expected substring world")
}

fn fail_string_match_regex() -> Result(AssertionResult, String) {
  "abc"
  |> should
  |> match_regex("^\\d+$")
  |> or_fail_with(
    "intentional StringMatchFailure: expected digits-only regex match",
  )
}

fn fail_snapshot_mismatch() -> Result(AssertionResult, String) {
  "actual snapshot content"
  |> should
  |> match_snapshot("./test/snapshots/intentional_snapshot_failure.snap")
  |> or_fail_with("intentional SnapshotFailure: expected snapshot mismatch")
}

fn fail_custom_matcher() -> Result(AssertionResult, String) {
  3
  |> should
  |> be_even_int()
  |> or_fail_with("intentional CustomMatcherFailure: expected even number")
}

fn be_even_int(value_or_result: MatchResult(Int)) -> MatchResult(Int) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_is_even_int(actual)
  }
}

fn check_is_even_int(actual: Int) -> MatchResult(Int) {
  case actual % 2 == 0 {
    True -> MatchOk(actual)
    False ->
      MatchFailed(AssertionFailure(
        operator: "be_even_int",
        message: "",
        payload: Some(CustomMatcherFailure(
          actual: int.to_string(actual),
          description: "expected an even number",
        )),
      ))
  }
}
