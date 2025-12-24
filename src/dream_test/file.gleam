//// File operations for dream_test.
////
//// Dream Test uses this module internally for snapshot testing and Gherkin file
//// parsing. It wraps Erlang file operations with a small, structured error type
//// (`FileError`) so callers can decide how to handle failures.
////
//// ## Example
////
//// Use this in test code (for example inside a snippet `tests()` function).
////
//// ```gleam
//// let path = tmp_path()
////
//// // Setup: create the file (no assertions during setup)
//// use _ <- result.try(
////   write(path, "hello") |> result.map_error(error_to_string),
//// )
////
//// read(path)
//// |> should
//// |> be_equal(Ok("hello"))
//// |> or_fail_with("expected to read back written content")
//// ```

// =============================================================================
// Error Types
// =============================================================================

/// Errors that can occur during file operations.
///
/// Each variant captures the file path and provides specific information
/// about what went wrong. Use `error_to_string` to format for display.
///
/// ## Variants
///
/// | Variant            | Cause                                         |
/// |--------------------|-----------------------------------------------|
/// | `NotFound`         | File or directory does not exist              |
/// | `PermissionDenied` | No read/write permission for the path         |
/// | `IsDirectory`      | Expected a file, got a directory              |
/// | `NoSpace`          | Disk full or quota exceeded                   |
/// | `FileSystemError`  | Other OS-level error (with reason string)     |
///
/// ## Example
///
/// ```gleam
/// error_to_string(NotFound("/x"))
/// |> should
/// |> be_equal("File not found: /x")
/// |> or_fail_with("expected NotFound formatting")
/// ```
///
pub type FileError {
  /// File or directory not found.
  ///
  /// The path field contains the missing path. This is the most common
  /// error—returned when trying to read a file that doesn't exist.
  NotFound(path: String)

  /// Permission denied for the operation.
  ///
  /// The current user lacks read or write permission for this path.
  /// On Unix systems, check the file permissions with `ls -la`.
  PermissionDenied(path: String)

  /// Path is a directory, not a file.
  ///
  /// Returned when attempting file operations (read/write) on a directory.
  IsDirectory(path: String)

  /// No space left on device.
  ///
  /// The disk is full or the user has exceeded their quota.
  /// Free up space or write to a different location.
  NoSpace(path: String)

  /// Other file system error with the raw reason.
  ///
  /// This captures any error not covered by the specific variants above.
  /// The `reason` field contains the Erlang error atom as a string
  /// (e.g., "ebusy", "emfile").
  FileSystemError(path: String, reason: String)
}

/// Convert a `FileError` to a human-readable string.
///
/// Formats the error with both the error type and the affected path,
/// suitable for logging or displaying to users.
///
/// ## Parameters
///
/// - `error`: the `FileError` value to format
///
/// ## Returns
///
/// A human-readable message string. This function is pure (no I/O).
///
/// ## Examples
///
/// ```gleam
/// error_to_string(NotFound("/x"))
/// |> should
/// |> be_equal("File not found: /x")
/// |> or_fail_with("expected NotFound formatting")
/// ```
///
pub fn error_to_string(error error: FileError) -> String {
  case error {
    NotFound(path) -> "File not found: " <> path
    PermissionDenied(path) -> "Permission denied: " <> path
    IsDirectory(path) -> "Is a directory: " <> path
    NoSpace(path) -> "No space left on device: " <> path
    FileSystemError(path, reason) -> "File error (" <> reason <> "): " <> path
  }
}

// =============================================================================
// File Operations
// =============================================================================

/// Read the entire contents of a file as a UTF-8 string.
///
/// Returns the file contents on success, or a `FileError` describing
/// what went wrong.
///
/// ## Parameters
///
/// - `path` - Path to the file (absolute or relative to cwd)
///
/// ## Returns
///
/// - `Ok(String)` - The file contents
/// - `Error(NotFound)` - File doesn't exist
/// - `Error(PermissionDenied)` - Can't read the file
/// - `Error(IsDirectory)` - Path is a directory
/// - `Error(FileSystemError)` - Other OS error
///
/// ## Examples
///
/// ```gleam
/// let path = tmp_path()
///
/// // Setup: create the file (no assertions during setup)
/// use _ <- result.try(
///   write(path, "hello") |> result.map_error(error_to_string),
/// )
///
/// read(path)
/// |> should
/// |> be_equal(Ok("hello"))
/// |> or_fail_with("expected to read back written content")
/// ```
///
@external(erlang, "dream_test_file_ffi", "read_file")
pub fn read(path path: String) -> Result(String, FileError)

/// Write a string to a file, creating parent directories if needed.
///
/// If the file exists, it will be completely overwritten.
/// If parent directories don't exist, they will be created automatically.
///
/// ## Parameters
///
/// - `path` - Destination path (absolute or relative to cwd)
/// - `content` - String content to write
///
/// ## Returns
///
/// - `Ok(Nil)` - File written successfully
/// - `Error(PermissionDenied)` - Can't write to the path
/// - `Error(NoSpace)` - Disk is full
/// - `Error(IsDirectory)` - Path is a directory
/// - `Error(FileSystemError)` - Other OS error
///
/// ## Examples
///
/// ```gleam
/// let path = tmp_path()
///
/// // Setup: create the file (no assertions during setup)
/// use _ <- result.try(
///   write(path, "hello") |> result.map_error(error_to_string),
/// )
/// ```
///
@external(erlang, "dream_test_file_ffi", "write_file")
pub fn write(
  path path: String,
  content content: String,
) -> Result(Nil, FileError)

/// Delete a file.
///
/// This operation is **idempotent**: deleting a file that doesn't exist
/// returns `Ok(Nil)`, not an error. This makes cleanup code simpler.
///
/// ## Parameters
///
/// - `path` - Path to the file to delete
///
/// ## Returns
///
/// - `Ok(Nil)` - File was deleted (or didn't exist)
/// - `Error(PermissionDenied)` - Can't delete the file
/// - `Error(IsDirectory)` - Path is a directory (use rmdir)
/// - `Error(FileSystemError)` - Other OS error
///
/// ## Examples
///
/// ```gleam
/// let path = tmp_path()
///
/// // Setup: create the file, then delete it (no assertions during setup)
/// use _ <- result.try(
///   write(path, "hello") |> result.map_error(error_to_string),
/// )
/// use _ <- result.try(delete(path) |> result.map_error(error_to_string))
///
/// read(path)
/// |> should
/// |> be_equal(Error(NotFound(path)))
/// |> or_fail_with("expected deleted file to be NotFound")
/// ```
///
@external(erlang, "dream_test_file_ffi", "delete_file")
pub fn delete(path path: String) -> Result(Nil, FileError)

/// Delete all files in a directory that have a specific extension.
///
/// Searches the given directory (non-recursively) for files matching
/// the extension pattern and deletes them. Returns the count of files
/// actually deleted.
///
/// ## Parameters
///
/// - `directory` - Path to the directory to search
/// - `extension` - File extension including the dot (e.g., ".snap", ".tmp")
///
/// ## Returns
///
/// - `Ok(Int)` - Number of files deleted
/// - `Error(FileError)` - Directory access failed (the specific variant depends on the underlying file system error)
///
/// ## Examples
///
/// ```gleam
/// let directory = "./test/tmp/file_helpers_" <> int.to_string(unique_port())
/// let a = directory <> "/a.snap"
/// let b = directory <> "/b.snap"
/// let keep = directory <> "/keep.txt"
///
/// // Setup: create 2 matching files and 1 non-matching file
/// use _ <- result.try(write(a, "a") |> result.map_error(error_to_string))
/// use _ <- result.try(write(b, "b") |> result.map_error(error_to_string))
/// use _ <- result.try(
///   write(keep, "keep") |> result.map_error(error_to_string),
/// )
///
/// delete_files_matching(directory, ".snap")
/// |> should
/// |> be_equal(Ok(2))
/// |> or_fail_with("expected two deleted snapshots")
/// ```
///
/// ## Notes
///
/// - Only searches the immediate directory (not subdirectories)
/// - Files that can't be deleted are silently skipped
/// - The count reflects only successfully deleted files
///
@external(erlang, "dream_test_file_ffi", "delete_files_matching")
pub fn delete_files_matching(
  directory directory: String,
  extension extension: String,
) -> Result(Int, FileError)
