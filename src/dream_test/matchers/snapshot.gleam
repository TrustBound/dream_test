//// Snapshot matchers for dream_test.
////
//// Snapshot testing compares a value against a stored "golden" file.
//// On first run, the snapshot is created automatically. On subsequent runs,
//// the value is compared against the stored snapshot—any difference is a failure.
////
//// ## Why Snapshot Testing?
////
//// Snapshot tests excel at detecting **unintended changes** in complex outputs:
////
//// - Rendered HTML/JSON/XML
//// - Error messages and logs
//// - Serialized data structures
//// - Any output where "expected" is hard to specify manually
////
//// ## Basic Usage
////
//// ```gleam
//// import dream_test/assertions/should.{should, match_snapshot, or_fail_with}
////
//// it("renders user profile", fn() {
////   render_profile(user)
////   |> should()
////   |> match_snapshot("./test/snapshots/user_profile.snap")
////   |> or_fail_with("Profile should match snapshot")
//// })
//// ```
////
//// ## How It Works
////
//// | Scenario              | Behavior                                  |
//// |-----------------------|-------------------------------------------|
//// | Snapshot missing      | Creates it, test **passes**               |
//// | Snapshot matches      | Test **passes**                           |
//// | Snapshot differs      | Test **fails** with diff                  |
////
//// ## Updating Snapshots
////
//// When you intentionally change output, update snapshots by deleting them:
////
//// ```bash
//// # Update one snapshot
//// rm ./test/snapshots/user_profile.snap
//// gleam test
////
//// # Update all snapshots in a directory
//// rm ./test/snapshots/*.snap
//// gleam test
//// ```
////
//// Or use the helper functions:
////
//// ```gleam
//// // In a setup script or before tests
//// let _ = snapshot.clear_snapshot("./test/snapshots/user_profile.snap")
//// let _ = snapshot.clear_snapshots_in_directory("./test/snapshots")
//// ```
////
//// ## Snapshot File Organization
////
//// Recommended structure:
////
//// ```text
//// test/
//// ├── snapshots/
//// │   ├── api/
//// │   │   ├── users_list.snap
//// │   │   └── user_detail.snap
//// │   └── components/
//// │       ├── header.snap
//// │       └── footer.snap
//// └── my_test.gleam
//// ```
////
//// Use descriptive paths that mirror your test structure.
////
//// ## Testing Non-Strings
////
//// For complex data structures, use `match_snapshot_inspect`:
////
//// ```gleam
//// build_complex_result()
//// |> should()
//// |> match_snapshot_inspect("./test/snapshots/complex.snap")
//// |> or_fail_with("Result should match snapshot")
//// ```
////
//// This uses Gleam's `string.inspect` to serialize the value.

import dream_test/file
import dream_test/types.{
  type MatchResult, AssertionFailure, MatchFailed, MatchOk, SnapshotFailure,
}
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
/// ## Examples
///
/// ### Basic Usage
///
/// ```gleam
/// it("serializes user to JSON", fn() {
///   user_to_json(sample_user)
///   |> should()
///   |> match_snapshot("./test/snapshots/user.json")
///   |> or_fail_with("User JSON should match snapshot")
/// })
/// ```
///
/// ### With Transformation
///
/// ```gleam
/// it("renders HTML correctly", fn() {
///   render_page(data)
///   |> string.trim()  // Normalize whitespace
///   |> should()
///   |> match_snapshot("./test/snapshots/page.html")
///   |> or_fail_with("Page HTML should match snapshot")
/// })
/// ```
///
/// ### Error Handling
///
/// ```gleam
/// it("handles parse errors gracefully", fn() {
///   case parse(invalid_input) {
///     Ok(_) -> fail("Should have failed")
///     Error(msg) ->
///       msg
///       |> should()
///       |> match_snapshot("./test/snapshots/parse_error.snap")
///       |> or_fail_with("Error message should match snapshot")
///   }
/// })
/// ```
///
/// ## Updating the Snapshot
///
/// ```bash
/// rm ./test/snapshots/user.json && gleam test
/// ```
///
pub fn match_snapshot(
  value_or_result: MatchResult(String),
  snapshot_path: String,
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
/// ## Examples
///
/// ### Testing a Record
///
/// ```gleam
/// it("parses config correctly", fn() {
///   parse_config(raw_toml)
///   |> should()
///   |> match_snapshot_inspect("./test/snapshots/config.snap")
///   |> or_fail_with("Parsed config should match snapshot")
/// })
/// ```
///
/// ### Testing a List
///
/// ```gleam
/// it("filters users correctly", fn() {
///   users
///   |> list.filter(is_active)
///   |> should()
///   |> match_snapshot_inspect("./test/snapshots/active_users.snap")
///   |> or_fail_with("Active users should match snapshot")
/// })
/// ```
///
/// ## Snapshot Format
///
/// The snapshot will contain the Gleam debug representation:
///
/// ```text
/// User(name: "Alice", age: 30, active: True)
/// ```
///
/// ```text
/// [User(name: "Alice", age: 30), User(name: "Bob", age: 25)]
/// ```
///
/// ## Note on Stability
///
/// The `string.inspect` output may change between Gleam versions.
/// If you need stable serialization, convert to JSON or another format
/// and use `match_snapshot` instead.
///
pub fn match_snapshot_inspect(
  value_or_result: MatchResult(value),
  snapshot_path: String,
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
/// ## Examples
///
/// ### Clear Before Test
///
/// ```gleam
/// // In a test setup
/// let _ = snapshot.clear_snapshot("./test/snapshots/user.snap")
/// // Next test will create a fresh snapshot
/// ```
///
/// ### Conditional Update
///
/// ```gleam
/// case env.get("UPDATE_SNAPSHOTS") {
///   Ok("true") -> {
///     let _ = snapshot.clear_snapshot("./test/snapshots/output.snap")
///   }
///   _ -> Nil
/// }
/// ```
///
/// ## Idempotent Behavior
///
/// This function succeeds even if the file doesn't exist:
///
/// ```gleam
/// // Both calls succeed
/// let _ = snapshot.clear_snapshot("./test/snapshots/new.snap")
/// let _ = snapshot.clear_snapshot("./test/snapshots/new.snap")
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
/// ## Examples
///
/// ### Clear All Snapshots
///
/// ```gleam
/// case snapshot.clear_snapshots_in_directory("./test/snapshots") {
///   Ok(0) -> io.println("No snapshots to clear")
///   Ok(n) -> io.println("Cleared " <> int.to_string(n) <> " snapshots")
///   Error(msg) -> io.println("Error: " <> msg)
/// }
/// ```
///
/// ### Clear Subdirectory
///
/// ```gleam
/// // Clear only API snapshots
/// let _ = snapshot.clear_snapshots_in_directory("./test/snapshots/api")
/// ```
///
/// ## Notes
///
/// - Only deletes files with `.snap` extension
/// - Does **not** recurse into subdirectories
/// - Non-snapshot files are left untouched
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
    Ok(expected) -> compare_snapshot(actual, expected, snapshot_path)
    Error(file.NotFound(_)) -> create_snapshot(actual, snapshot_path)
    Error(error) -> make_read_error_failure(snapshot_path, error)
  }
}

fn compare_snapshot(
  actual: String,
  expected: String,
  snapshot_path: String,
) -> MatchResult(String) {
  case actual == expected {
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
      compare_snapshot_inspect(value, serialized, expected, snapshot_path)
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
