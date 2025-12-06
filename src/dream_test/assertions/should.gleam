//// Assertion API for dream_test.
////
//// This module provides a fluent, pipe-friendly assertion API. Every assertion
//// chain starts with `should()` and ends with `or_fail_with()`.
////
//// ## Basic Pattern
////
//// ```gleam
//// value
//// |> should()
//// |> equal(expected)
//// |> or_fail_with("Helpful error message")
//// ```
////
//// ## Available Matchers
////
//// | Category       | Matchers                                                    |
//// |----------------|-------------------------------------------------------------|
//// | **Equality**   | `equal`, `not_equal`                                        |
//// | **Boolean**    | `be_true`, `be_false`                                       |
//// | **Option**     | `be_some`, `be_none`                                        |
//// | **Result**     | `be_ok`, `be_error`                                         |
//// | **Collections**| `contain`, `not_contain`, `have_length`, `be_empty`         |
//// | **Comparison** | `be_greater_than`, `be_less_than`, `be_at_least`, `be_at_most`, `be_between`, `be_in_range` |
//// | **String**     | `start_with`, `end_with`, `contain_string`                  |
//// | **Snapshot**   | `match_snapshot`, `match_snapshot_inspect`                  |
////
//// ## Chaining Matchers
////
//// Matchers can be chained. Each matcher passes its unwrapped value to the next:
////
//// ```gleam
//// // Unwrap Some, then check the inner value
//// Some(42)
//// |> should()
//// |> be_some()
//// |> equal(42)
//// |> or_fail_with("Should be Some(42)")
////
//// // Unwrap Ok, then check the inner value
//// Ok("hello")
//// |> should()
//// |> be_ok()
//// |> equal("hello")
//// |> or_fail_with("Should be Ok with 'hello'")
////
//// // Unwrap Ok, then check the inner Option
//// Ok(Some(42))
//// |> should()
//// |> be_ok()
//// |> be_some()
//// |> be_greater_than(40)
//// |> or_fail_with("Should be Ok(Some(n)) where n > 40")
//// ```
////
//// ## Explicit Failures
////
//// Sometimes you need to fail a test explicitly in a conditional branch:
////
//// ```gleam
//// case result {
////   Ok(user) -> {
////     user.name
////     |> should()
////     |> equal("Alice")
////     |> or_fail_with("User should be Alice")
////   }
////   Error(_) -> fail_with("Should have returned a user")
//// }
//// ```
////
//// ## Import Style
////
//// For best readability, import the commonly used functions unqualified:
////
//// ```gleam
//// import dream_test/assertions/should.{
////   should, equal, be_ok, be_some, or_fail_with, fail_with, succeed,
//// }
//// ```

import dream_test/matchers/boolean
import dream_test/matchers/collection
import dream_test/matchers/comparison
import dream_test/matchers/equality
import dream_test/matchers/option
import dream_test/matchers/result
import dream_test/matchers/snapshot
import dream_test/matchers/string
import dream_test/types.{
  type AssertionResult, type MatchResult, AssertionFailed, AssertionFailure,
  AssertionOk, MatchFailed, MatchOk,
}
import gleam/option as gleam_option

/// Start an assertion chain.
///
/// This wraps any value in a `MatchResult` so it can be piped into matchers.
/// Every assertion chain should start with this function.
///
/// ## Example
///
/// ```gleam
/// 42
/// |> should()
/// |> equal(42)
/// |> or_fail_with("Should be 42")
/// ```
///
pub fn should(value: a) -> MatchResult(a) {
  MatchOk(value)
}

// =============================================================================
// Equality Matchers
// =============================================================================

/// Assert that a value equals the expected value.
///
/// Uses Gleam's structural equality (`==`).
///
/// ## Example
///
/// ```gleam
/// add(2, 3)
/// |> should()
/// |> equal(5)
/// |> or_fail_with("2 + 3 should equal 5")
/// ```
///
pub const equal = equality.equal

/// Assert that a value does not equal the unexpected value.
///
/// ## Example
///
/// ```gleam
/// divide(10, 3)
/// |> should()
/// |> not_equal(3)
/// |> or_fail_with("10/3 should not equal 3 exactly")
/// ```
///
pub const not_equal = equality.not_equal

// =============================================================================
// Boolean Matchers
// =============================================================================

/// Assert that a value is `True`.
///
/// ## Example
///
/// ```gleam
/// is_valid(input)
/// |> should()
/// |> be_true()
/// |> or_fail_with("Input should be valid")
/// ```
///
pub const be_true = boolean.be_true

/// Assert that a value is `False`.
///
/// ## Example
///
/// ```gleam
/// is_empty(list)
/// |> should()
/// |> be_false()
/// |> or_fail_with("List should not be empty")
/// ```
///
pub const be_false = boolean.be_false

// =============================================================================
// Option Matchers
// =============================================================================

/// Assert that an `Option` is `Some` and extract its value.
///
/// If the assertion passes, the inner value is passed to subsequent matchers.
/// This enables chaining like `be_some() |> equal(42)`.
///
/// ## Example
///
/// ```gleam
/// find_user(id)
/// |> should()
/// |> be_some()
/// |> or_fail_with("User should exist")
///
/// // With chaining:
/// find_user(id)
/// |> should()
/// |> be_some()
/// |> equal(expected_user)
/// |> or_fail_with("Should find the expected user")
/// ```
///
pub const be_some = option.be_some

/// Assert that an `Option` is `None`.
///
/// ## Example
///
/// ```gleam
/// find_deleted_user(id)
/// |> should()
/// |> be_none()
/// |> or_fail_with("Deleted user should not exist")
/// ```
///
pub const be_none = option.be_none

// =============================================================================
// Result Matchers
// =============================================================================

/// Assert that a `Result` is `Ok` and extract its value.
///
/// If the assertion passes, the `Ok` value is passed to subsequent matchers.
/// This enables chaining like `be_ok() |> equal(42)`.
///
/// ## Example
///
/// ```gleam
/// parse_int("42")
/// |> should()
/// |> be_ok()
/// |> or_fail_with("Should parse successfully")
///
/// // With chaining:
/// parse_int("42")
/// |> should()
/// |> be_ok()
/// |> equal(42)
/// |> or_fail_with("Should parse to 42")
/// ```
///
pub const be_ok = result.be_ok

/// Assert that a `Result` is `Error` and extract the error value.
///
/// If the assertion passes, the error value is passed to subsequent matchers.
///
/// ## Example
///
/// ```gleam
/// parse_int("not a number")
/// |> should()
/// |> be_error()
/// |> or_fail_with("Should fail to parse")
///
/// // With chaining:
/// validate(input)
/// |> should()
/// |> be_error()
/// |> equal(ValidationError("email required"))
/// |> or_fail_with("Should fail with email error")
/// ```
///
pub const be_error = result.be_error

// =============================================================================
// Collection Matchers
// =============================================================================

/// Assert that a list contains a specific item.
///
/// ## Example
///
/// ```gleam
/// [1, 2, 3]
/// |> should()
/// |> contain(2)
/// |> or_fail_with("List should contain 2")
/// ```
///
pub const contain = collection.contain

/// Assert that a list does not contain a specific item.
///
/// ## Example
///
/// ```gleam
/// ["a", "b", "c"]
/// |> should()
/// |> not_contain("d")
/// |> or_fail_with("List should not contain 'd'")
/// ```
///
pub const not_contain = collection.not_contain

/// Assert that a list has a specific length.
///
/// ## Example
///
/// ```gleam
/// get_users()
/// |> should()
/// |> have_length(3)
/// |> or_fail_with("Should have 3 users")
/// ```
///
pub const have_length = collection.have_length

/// Assert that a list is empty.
///
/// ## Example
///
/// ```gleam
/// get_errors()
/// |> should()
/// |> be_empty()
/// |> or_fail_with("Should have no errors")
/// ```
///
pub const be_empty = collection.be_empty

// =============================================================================
// Comparison Matchers (Int)
// =============================================================================

/// Assert that an integer is greater than a threshold.
///
/// ## Example
///
/// ```gleam
/// count_items()
/// |> should()
/// |> be_greater_than(0)
/// |> or_fail_with("Should have at least one item")
/// ```
///
pub const be_greater_than = comparison.be_greater_than

/// Assert that an integer is less than a threshold.
///
/// ## Example
///
/// ```gleam
/// response_time_ms
/// |> should()
/// |> be_less_than(100)
/// |> or_fail_with("Response should be under 100ms")
/// ```
///
pub const be_less_than = comparison.be_less_than

/// Assert that an integer is at least a minimum value (>=).
///
/// ## Example
///
/// ```gleam
/// user.age
/// |> should()
/// |> be_at_least(18)
/// |> or_fail_with("User must be at least 18")
/// ```
///
pub const be_at_least = comparison.be_at_least

/// Assert that an integer is at most a maximum value (<=).
///
/// ## Example
///
/// ```gleam
/// password.length
/// |> should()
/// |> be_at_most(128)
/// |> or_fail_with("Password must be at most 128 characters")
/// ```
///
pub const be_at_most = comparison.be_at_most

/// Assert that an integer is between two values (exclusive).
///
/// The value must be strictly greater than `min` and strictly less than `max`.
///
/// ## Example
///
/// ```gleam
/// port
/// |> should()
/// |> be_between(1024, 65535)
/// |> or_fail_with("Port must be between 1024 and 65535")
/// ```
///
pub const be_between = comparison.be_between

/// Assert that an integer is within a range (inclusive).
///
/// The value must be >= `min` and <= `max`.
///
/// ## Example
///
/// ```gleam
/// score
/// |> should()
/// |> be_in_range(0, 100)
/// |> or_fail_with("Score must be 0-100")
/// ```
///
pub const be_in_range = comparison.be_in_range

/// Assert that a float is greater than a threshold.
///
/// ## Example
///
/// ```gleam
/// average
/// |> should()
/// |> be_greater_than_float(0.0)
/// |> or_fail_with("Average should be positive")
/// ```
///
pub const be_greater_than_float = comparison.be_greater_than_float

/// Assert that a float is less than a threshold.
///
/// ## Example
///
/// ```gleam
/// error_rate
/// |> should()
/// |> be_less_than_float(0.01)
/// |> or_fail_with("Error rate should be under 1%")
/// ```
///
pub const be_less_than_float = comparison.be_less_than_float

// =============================================================================
// String Matchers
// =============================================================================

/// Assert that a string starts with a prefix.
///
/// ## Example
///
/// ```gleam
/// greeting
/// |> should()
/// |> start_with("Hello")
/// |> or_fail_with("Greeting should start with Hello")
/// ```
///
pub const start_with = string.start_with

/// Assert that a string ends with a suffix.
///
/// ## Example
///
/// ```gleam
/// filename
/// |> should()
/// |> end_with(".gleam")
/// |> or_fail_with("File should be a Gleam file")
/// ```
///
pub const end_with = string.end_with

/// Assert that a string contains a substring.
///
/// ## Example
///
/// ```gleam
/// log_message
/// |> should()
/// |> contain_string("error")
/// |> or_fail_with("Log should mention error")
/// ```
///
pub const contain_string = string.contain_string

// =============================================================================
// Snapshot Matchers
// =============================================================================

/// Assert that a string matches the content of a snapshot file.
///
/// - If snapshot **doesn't exist**: creates it and passes
/// - If snapshot **exists and matches**: passes
/// - If snapshot **exists but doesn't match**: fails
///
/// **To update a snapshot:** delete the file and re-run the test.
///
/// ## Example
///
/// ```gleam
/// render_html()
/// |> should()
/// |> match_snapshot("./test/snapshots/page.snap")
/// |> or_fail_with("HTML should match snapshot")
/// ```
///
pub const match_snapshot = snapshot.match_snapshot

/// Assert that any value matches a snapshot (using string.inspect).
///
/// Serializes the value using `string.inspect` and compares against
/// the stored snapshot. Useful for testing complex data structures.
///
/// ## Example
///
/// ```gleam
/// build_config()
/// |> should()
/// |> match_snapshot_inspect("./test/snapshots/config.snap")
/// |> or_fail_with("Config should match snapshot")
/// ```
///
pub const match_snapshot_inspect = snapshot.match_snapshot_inspect

/// Delete a snapshot file.
///
/// Use this to force regeneration of a snapshot on the next test run.
///
/// ## Example
///
/// ```gleam
/// let _ = clear_snapshot("./test/snapshots/old.snap")
/// ```
///
pub const clear_snapshot = snapshot.clear_snapshot

/// Delete all snapshot files in a directory.
///
/// Deletes all files with the `.snap` extension in the given directory.
///
/// ## Example
///
/// ```gleam
/// let _ = clear_snapshots_in_directory("./test/snapshots")
/// ```
///
pub const clear_snapshots_in_directory = snapshot.clear_snapshots_in_directory

// =============================================================================
// Terminal Operations
// =============================================================================

/// Complete an assertion chain and provide a failure message.
///
/// This is the **terminal operation** that ends every assertion chain. It
/// converts the `MatchResult` into an `AssertionResult` that the test runner
/// understands.
///
/// If the assertion passed, returns `AssertionOk`. If it failed, returns
/// `AssertionFailed` with the provided message.
///
/// ## Example
///
/// ```gleam
/// result
/// |> should()
/// |> equal(42)
/// |> or_fail_with("Result should be 42")
/// ```
///
/// ## Writing Good Messages
///
/// Good failure messages explain **what should have happened**:
/// - ✓ "User should be authenticated after login"
/// - ✓ "Cart total should include tax"
/// - ✗ "wrong"
/// - ✗ "failed"
///
pub fn or_fail_with(result: MatchResult(a), message: String) -> AssertionResult {
  case result {
    MatchOk(_) -> AssertionOk

    MatchFailed(failure) ->
      AssertionFailed(AssertionFailure(..failure, message: message))
  }
}

/// Explicitly fail a test with a message.
///
/// Use this when you need to fail a test in a conditional branch where
/// the normal assertion chain doesn't apply.
///
/// ## Example
///
/// ```gleam
/// case result {
///   Ok(value) -> {
///     value
///     |> should()
///     |> equal(expected)
///     |> or_fail_with("Value should match")
///   }
///   Error(_) -> fail_with("Should have succeeded but got an error")
/// }
/// ```
///
/// ## When to Use
///
/// - In `case` branches that represent unexpected states
/// - When testing that something does NOT happen
/// - As a placeholder for unimplemented test branches
///
pub fn fail_with(message: String) -> AssertionResult {
  AssertionFailed(AssertionFailure(
    operator: "fail_with",
    message: message,
    payload: gleam_option.None,
  ))
}

/// Explicitly mark an assertion as successful.
///
/// Use this when you need to explicitly succeed in a conditional branch,
/// as the counterpart to `fail_with`.
///
/// ## Example
///
/// ```gleam
/// case result {
///   Ok(_) -> succeed()
///   Error(_) -> fail_with("Should have succeeded")
/// }
/// ```
///
/// ## When to Use
///
/// - In `case` branches where success is the expected outcome
/// - When all branches of a case must return an `AssertionResult`
/// - To make intent explicit rather than relying on implicit success
///
pub fn succeed() -> AssertionResult {
  AssertionOk
}
