//// Snapshot matchers for dream_test.
////
//// Snapshot testing compares output against a stored “golden” file.
////
//// - On first run (missing snapshot), the snapshot is created and the test passes.
//// - On later runs, the output is compared against the file; differences fail.
////
//// Snapshot tests are useful when the output is large or awkward to specify by
//// hand (rendered HTML, JSON, error messages, logs, etc.).
////
//// ## Example
////
//// ```gleam
//// let path = "./test/tmp/match_snapshot_example.snap"
//// "hello"
//// |> should
//// |> match_snapshot(path)
//// |> or_fail_with("expected snapshot match")
//// ```

import dream_test/file
import dream_test/types.{
  type MatchResult, AssertionFailure, MatchFailed, MatchOk, SnapshotFailure,
}
import gleam/list
import gleam/option.{Some}
import gleam/string

// =============================================================================
// Public API - Matchers
// =============================================================================

/// Assert that a string value matches the content of a snapshot file.
///
/// This is the primary snapshot matcher. Use it when you have string output
/// (JSON, HTML, plain text, etc.) that you want to compare against a snapshot.
///
/// ## Behavior
///
/// - **Snapshot doesn't exist**: Creates it and the test **passes**
/// - **Snapshot exists and matches**: Test **passes**
/// - **Snapshot exists but differs**: Test **fails** with detailed diff
///
/// ## Parameters
///
/// - `value_or_result` - The `MatchResult(String)` from the assertion chain
/// - `snapshot_path` - Path to the snapshot file (will be created if missing)
///
/// ## Example
///
/// ```gleam
/// let path = "./test/tmp/match_snapshot_example.snap"
/// "hello"
/// |> should
/// |> match_snapshot(path)
/// |> or_fail_with("expected snapshot match")
/// ```
///
/// ## Returns
///
/// A `MatchResult(String)`:
/// - On success, preserves the original string for further chaining.
/// - On failure, the chain becomes failed and later matchers are skipped.
///
pub fn match_snapshot(
  value_or_result value_or_result: MatchResult(String),
  snapshot_path snapshot_path: String,
) -> MatchResult(String) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_snapshot(actual, snapshot_path)
  }
}

/// Assert that any value matches a snapshot when serialized.
///
/// Use this when testing complex data structures that aren't strings.
/// The value is converted to a string using `string.inspect`, which
/// produces Gleam's debug representation.
///
/// ## When to Use This
///
/// - Testing return values of functions (records, tuples, lists)
/// - Comparing parsed AST structures
/// - Verifying complex state after operations
///
/// ## Parameters
///
/// - `value_or_result` - The `MatchResult(value)` from the assertion chain
/// - `snapshot_path` - Path to the snapshot file
///
/// ## Example
///
/// ```gleam
/// let path = "./test/tmp/match_snapshot_inspect_example.snap"
/// Some(1)
/// |> should
/// |> match_snapshot_inspect(path)
/// |> or_fail_with("expected inspect snapshot match")
/// ```
///
/// ## Returns
///
/// A `MatchResult(value)`:
/// - On success, preserves the original value for further chaining.
/// - On failure, the chain becomes failed and later matchers are skipped.
///
pub fn match_snapshot_inspect(
  value_or_result value_or_result: MatchResult(value),
  snapshot_path snapshot_path: String,
) -> MatchResult(value) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(value) -> check_snapshot_inspect(value, snapshot_path)
  }
}

// =============================================================================
// Public API - Utilities
// =============================================================================

/// Delete a snapshot file to force regeneration.
///
/// Use this to programmatically clear a snapshot. The next test run will
/// create a fresh snapshot with the current output.
///
/// ## Parameters
///
/// - `snapshot_path` - Path to the snapshot file to delete
///
/// ## Returns
///
/// - `Ok(Nil)` - Snapshot was deleted (or didn't exist)
/// - `Error(String)` - Human-readable error message
///
/// ## Example
///
/// ```gleam
/// let path = "./test/tmp/clear_snapshot_example.snap"
///
/// // Setup: create a snapshot file (no assertions during setup)
/// use _ <- result.try(
///   file.write(path, "hello") |> result.map_error(file.error_to_string),
/// )
///
/// clear_snapshot(path)
/// |> should
/// |> be_equal(Ok(Nil))
/// |> or_fail_with("expected clear_snapshot to succeed")
/// ```
///
pub fn clear_snapshot(snapshot_path: String) -> Result(Nil, String) {
  case file.delete(snapshot_path) {
    Ok(Nil) -> Ok(Nil)
    Error(error) -> Error(file.error_to_string(error))
  }
}

/// Delete all `.snap` files in a directory.
///
/// Clears all snapshot files in the given directory (non-recursively).
/// Useful for resetting all snapshots before a major refactor.
///
/// ## Parameters
///
/// - `directory` - Path to the directory containing snapshots
///
/// ## Returns
///
/// - `Ok(Int)` - Number of snapshot files deleted
/// - `Error(String)` - Human-readable error message
///
/// ## Example
///
/// ```gleam
/// let directory = "./test/tmp/clear_snapshots_in_directory_example"
/// let a = directory <> "/a.snap"
/// let b = directory <> "/b.snap"
///
/// // Setup: create two snapshot files (no assertions during setup)
/// use _ <- result.try(
///   file.write(a, "a") |> result.map_error(file.error_to_string),
/// )
/// use _ <- result.try(
///   file.write(b, "b") |> result.map_error(file.error_to_string),
/// )
///
/// clear_snapshots_in_directory(directory)
/// |> should
/// |> be_equal(Ok(2))
/// |> or_fail_with("expected two deleted snapshots")
/// ```
///
pub fn clear_snapshots_in_directory(directory: String) -> Result(Int, String) {
  case file.delete_files_matching(directory, ".snap") {
    Ok(count) -> Ok(count)
    Error(error) -> Error(file.error_to_string(error))
  }
}

// =============================================================================
// Internal Implementation
// =============================================================================

fn check_snapshot(actual: String, snapshot_path: String) -> MatchResult(String) {
  case file.read(snapshot_path) {
    Ok(expected) ->
      compare_snapshot(
        actual,
        normalize_snapshot_expected(expected),
        snapshot_path,
      )
    Error(file.NotFound(_)) -> create_snapshot(actual, snapshot_path)
    Error(error) -> make_read_error_failure(snapshot_path, error)
  }
}

fn normalize_snapshot_expected(expected: String) -> String {
  expected
  |> string.to_graphemes
  |> list.reverse
  |> drop_trailing_newlines
  |> list.reverse
  |> string.join("")
}

fn drop_trailing_newlines(graphemes_reversed: List(String)) -> List(String) {
  case graphemes_reversed {
    ["\n", ..rest] -> drop_trailing_newlines(rest)
    ["\r", ..rest] -> drop_trailing_newlines(rest)
    other -> other
  }
}

fn compare_snapshot(
  actual: String,
  expected: String,
  snapshot_path: String,
) -> MatchResult(String) {
  // Normalize both sides so trailing newlines in either the snapshot file
  // or the produced output don't create noisy, meaningless mismatches.
  let normalized_actual = normalize_snapshot_expected(actual)
  case normalized_actual == expected {
    True -> MatchOk(actual)
    False -> make_mismatch_failure(actual, expected, snapshot_path)
  }
}

fn make_mismatch_failure(
  actual: String,
  expected: String,
  snapshot_path: String,
) -> MatchResult(String) {
  let payload =
    SnapshotFailure(
      actual: actual,
      expected: expected,
      snapshot_path: snapshot_path,
      is_missing: False,
    )
  MatchFailed(AssertionFailure(
    operator: "match_snapshot",
    message: "",
    payload: Some(payload),
  ))
}

fn make_read_error_failure(
  snapshot_path: String,
  error: file.FileError,
) -> MatchResult(String) {
  let payload =
    SnapshotFailure(
      actual: "",
      expected: "",
      snapshot_path: snapshot_path,
      is_missing: True,
    )
  MatchFailed(AssertionFailure(
    operator: "match_snapshot",
    message: "Failed to read snapshot: " <> file.error_to_string(error),
    payload: Some(payload),
  ))
}

fn create_snapshot(actual: String, snapshot_path: String) -> MatchResult(String) {
  case file.write(snapshot_path, actual) {
    Ok(Nil) -> MatchOk(actual)
    Error(error) -> make_write_failure(snapshot_path, error)
  }
}

fn make_write_failure(
  snapshot_path: String,
  error: file.FileError,
) -> MatchResult(String) {
  let payload =
    SnapshotFailure(
      actual: "",
      expected: "",
      snapshot_path: snapshot_path,
      is_missing: True,
    )
  MatchFailed(AssertionFailure(
    operator: "match_snapshot",
    message: "Failed to write snapshot: " <> file.error_to_string(error),
    payload: Some(payload),
  ))
}

fn check_snapshot_inspect(
  value: value,
  snapshot_path: String,
) -> MatchResult(value) {
  let serialized = string.inspect(value)
  case file.read(snapshot_path) {
    Ok(expected) ->
      compare_snapshot_inspect(
        value,
        serialized,
        normalize_snapshot_expected(expected),
        snapshot_path,
      )
    Error(file.NotFound(_)) ->
      create_snapshot_inspect(value, serialized, snapshot_path)
    Error(error) -> make_read_error_failure_inspect(snapshot_path, error)
  }
}

fn compare_snapshot_inspect(
  value: value,
  serialized: String,
  expected: String,
  snapshot_path: String,
) -> MatchResult(value) {
  case serialized == expected {
    True -> MatchOk(value)
    False -> make_mismatch_failure_inspect(serialized, expected, snapshot_path)
  }
}

fn make_mismatch_failure_inspect(
  actual: String,
  expected: String,
  snapshot_path: String,
) -> MatchResult(value) {
  let payload =
    SnapshotFailure(
      actual: actual,
      expected: expected,
      snapshot_path: snapshot_path,
      is_missing: False,
    )
  MatchFailed(AssertionFailure(
    operator: "match_snapshot_inspect",
    message: "",
    payload: Some(payload),
  ))
}

fn make_read_error_failure_inspect(
  snapshot_path: String,
  error: file.FileError,
) -> MatchResult(value) {
  let payload =
    SnapshotFailure(
      actual: "",
      expected: "",
      snapshot_path: snapshot_path,
      is_missing: True,
    )
  MatchFailed(AssertionFailure(
    operator: "match_snapshot_inspect",
    message: "Failed to read snapshot: " <> file.error_to_string(error),
    payload: Some(payload),
  ))
}

fn create_snapshot_inspect(
  value: value,
  serialized: String,
  snapshot_path: String,
) -> MatchResult(value) {
  case file.write(snapshot_path, serialized) {
    Ok(Nil) -> MatchOk(value)
    Error(error) -> make_write_failure_inspect(snapshot_path, error)
  }
}

fn make_write_failure_inspect(
  snapshot_path: String,
  error: file.FileError,
) -> MatchResult(value) {
  let payload =
    SnapshotFailure(
      actual: "",
      expected: "",
      snapshot_path: snapshot_path,
      is_missing: True,
    )
  MatchFailed(AssertionFailure(
    operator: "match_snapshot_inspect",
    message: "Failed to write snapshot: " <> file.error_to_string(error),
    payload: Some(payload),
  ))
}
