//// File operations for dream_test.
////
//// This module provides file I/O operations for internal use by dream_test,
//// particularly for snapshot testing and Gherkin file parsing. It wraps
//// Erlang's file operations with proper error handling.
////
//// ## Error Handling
////
//// Unlike many file libraries that return opaque errors, this module provides
//// structured `FileError` types that tell you exactly what went wrong:
////
//// ```gleam
//// case file.read("config.json") {
////   Ok(content) -> parse(content)
////   Error(NotFound(_)) -> use_defaults()
////   Error(PermissionDenied(path)) -> panic as "Cannot read " <> path
////   Error(error) -> panic as file.error_to_string(error)
//// }
//// ```
////
//// ## Usage Examples
////
//// ### Reading Files
////
//// ```gleam
//// import dream_test/file
////
//// case file.read("./test/fixtures/expected.json") {
////   Ok(content) -> content
////   Error(error) -> {
////     io.println("Error: " <> file.error_to_string(error))
////     ""
////   }
//// }
//// ```
////
//// ### Writing Files
////
//// ```gleam
//// // Creates parent directories automatically
//// case file.write("./test/snapshots/output.snap", result) {
////   Ok(Nil) -> io.println("Saved!")
////   Error(NoSpace(_)) -> io.println("Disk full!")
////   Error(error) -> io.println(file.error_to_string(error))
//// }
//// ```
////
//// ### Deleting Files
////
//// ```gleam
//// // Safe to call even if file doesn't exist
//// let _ = file.delete("./test/snapshots/old.snap")
////
//// // Delete all snapshots
//// case file.delete_files_matching("./test/snapshots", ".snap") {
////   Ok(count) -> io.println("Deleted " <> int.to_string(count) <> " files")
////   Error(error) -> io.println(file.error_to_string(error))
//// }
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
/// case file.read("secret.txt") {
///   Ok(content) -> use(content)
///   Error(PermissionDenied(path)) -> {
///     io.println("Access denied: " <> path)
///     io.println("Try: chmod +r " <> path)
///   }
///   Error(NotFound(path)) -> {
///     io.println("File not found: " <> path)
///   }
///   Error(error) -> {
///     io.println(file.error_to_string(error))
///   }
/// }
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
/// ## Examples
///
/// ```gleam
/// error_to_string(NotFound("/app/config.json"))
/// // -> "File not found: /app/config.json"
///
/// error_to_string(PermissionDenied("/etc/shadow"))
/// // -> "Permission denied: /etc/shadow"
///
/// error_to_string(FileSystemError("/dev/null", "ebusy"))
/// // -> "File error (ebusy): /dev/null"
/// ```
///
pub fn error_to_string(error: FileError) -> String {
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
/// // Read a configuration file
/// case file.read("gleam.toml") {
///   Ok(toml) -> parse_config(toml)
///   Error(NotFound(_)) -> default_config()
///   Error(error) -> panic as file.error_to_string(error)
/// }
/// ```
///
/// ```gleam
/// // Read with full error handling
/// case file.read(path) {
///   Ok(content) -> Ok(content)
///   Error(NotFound(_)) -> Error("Config file missing")
///   Error(PermissionDenied(_)) -> Error("Cannot read config (permission denied)")
///   Error(error) -> Error(file.error_to_string(error))
/// }
/// ```
///
@external(erlang, "dream_test_file_ffi", "read_file")
pub fn read(path: String) -> Result(String, FileError)

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
/// // Write a snapshot file
/// case file.write("./test/snapshots/user.snap", json_output) {
///   Ok(Nil) -> io.println("Snapshot saved")
///   Error(error) -> io.println("Failed: " <> file.error_to_string(error))
/// }
/// ```
///
/// ```gleam
/// // Creates nested directories automatically
/// file.write("./deep/nested/path/file.txt", "content")
/// // Creates ./deep/nested/path/ if it doesn't exist
/// ```
///
@external(erlang, "dream_test_file_ffi", "write_file")
pub fn write(path: String, content: String) -> Result(Nil, FileError)

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
/// // Safe cleanup - doesn't fail if already deleted
/// let _ = file.delete("./test/temp/output.txt")
/// ```
///
/// ```gleam
/// // Delete with error handling
/// case file.delete(snapshot_path) {
///   Ok(Nil) -> io.println("Snapshot cleared")
///   Error(PermissionDenied(_)) -> io.println("Cannot delete (permission denied)")
///   Error(error) -> io.println(file.error_to_string(error))
/// }
/// ```
///
@external(erlang, "dream_test_file_ffi", "delete_file")
pub fn delete(path: String) -> Result(Nil, FileError)

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
/// - `Error(FileSystemError)` - Directory access failed
///
/// ## Examples
///
/// ```gleam
/// // Clear all snapshot files
/// case file.delete_files_matching("./test/snapshots", ".snap") {
///   Ok(0) -> io.println("No snapshots to delete")
///   Ok(n) -> io.println("Deleted " <> int.to_string(n) <> " snapshots")
///   Error(error) -> io.println(file.error_to_string(error))
/// }
/// ```
///
/// ```gleam
/// // Clean up temporary files before test run
/// let _ = file.delete_files_matching("./test/temp", ".tmp")
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
  directory: String,
  extension: String,
) -> Result(Int, FileError)
