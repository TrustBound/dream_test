import dream_test/file.{
  type FileError, FileSystemError, IsDirectory, NoSpace, NotFound,
  PermissionDenied, delete, delete_files_matching, error_to_string, read, write,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process.{unique_port}
import dream_test/unit.{describe, it}
import gleam/int

pub fn tests() {
  describe("dream_test/file", [
    it("write succeeds", fn() {
      let path =
        "./test/tmp/file_api_test/write_"
        <> int.to_string(unique_port())
        <> ".txt"
      write(path, "hello")
      |> should
      |> be_equal(Ok(Nil))
      |> or_fail_with("expected write to succeed")
    }),

    it("read returns written content", fn() {
      let path =
        "./test/tmp/file_api_test/read_"
        <> int.to_string(unique_port())
        <> ".txt"
      let _ = write(path, "hello")
      read(path)
      |> should
      |> be_equal(Ok("hello"))
      |> or_fail_with("expected read to return written content")
    }),

    it("delete succeeds", fn() {
      let path =
        "./test/tmp/file_api_test/delete_"
        <> int.to_string(unique_port())
        <> ".txt"
      let _ = write(path, "hello")
      delete(path)
      |> should
      |> be_equal(Ok(Nil))
      |> or_fail_with("expected delete to succeed")
    }),

    it("delete is idempotent", fn() {
      let path =
        "./test/tmp/file_api_test/delete_idempotent_"
        <> int.to_string(unique_port())
        <> ".txt"
      let _ = delete(path)
      delete(path)
      |> should
      |> be_equal(Ok(Nil))
      |> or_fail_with("expected delete to be idempotent")
    }),

    it("delete_files_matching returns count of deleted files", fn() {
      let dir =
        "./test/tmp/file_api_test/delete_files_matching_"
        <> int.to_string(unique_port())
      let a = dir <> "/a.tmp"
      let b = dir <> "/b.tmp"
      let c = dir <> "/c.other"
      let _ = write(a, "a")
      let _ = write(b, "b")
      let _ = write(c, "c")

      delete_files_matching(dir, ".tmp")
      |> should
      |> be_equal(Ok(2))
      |> or_fail_with("expected 2 tmp files deleted")
    }),

    it("delete_files_matching deletes matching files", fn() {
      let dir =
        "./test/tmp/file_api_test/delete_files_matching_deleted_"
        <> int.to_string(unique_port())
      let a = dir <> "/a.tmp"
      let _ = write(a, "a")
      let _ = delete_files_matching(dir, ".tmp")

      read(a)
      |> should
      |> be_equal(Error(NotFound(a)))
      |> or_fail_with("a.tmp should be deleted")
    }),

    it("delete_files_matching keeps non-matching files", fn() {
      let dir =
        "./test/tmp/file_api_test/delete_files_matching_keep_"
        <> int.to_string(unique_port())
      let c = dir <> "/c.other"
      let _ = write(c, "c")
      let _ = delete_files_matching(dir, ".tmp")

      read(c)
      |> should
      |> be_equal(Ok("c"))
      |> or_fail_with("c.other should remain")
    }),

    it("delete_files_matching reads a brace in the directory as text", fn() {
      let dir =
        "./test/tmp/file_api_test/brace{" <> int.to_string(unique_port())
      let _ = write(dir <> "/a.tmp", "a")
      let _ = write(dir <> "/b.tmp", "b")

      delete_files_matching(dir, ".tmp")
      |> should
      |> be_equal(Ok(2))
      |> or_fail_with("expected 2 tmp files deleted in the brace directory")
    }),

    it("delete_files_matching leaves a directory that a star would match", fn() {
      let id = int.to_string(unique_port())
      let star_dir = "./test/tmp/file_api_test/star_" <> id <> "*"
      let sibling = "./test/tmp/file_api_test/star_" <> id <> "x/a.tmp"
      let _ = write(star_dir <> "/a.tmp", "a")
      let _ = write(sibling, "sibling")
      let _ = delete_files_matching(star_dir, ".tmp")

      read(sibling)
      |> should
      |> be_equal(Ok("sibling"))
      |> or_fail_with("the sibling directory's file should remain")
    }),

    it("delete_files_matching gives 0 for a missing directory", fn() {
      let dir =
        "./test/tmp/file_api_test/missing_" <> int.to_string(unique_port())

      delete_files_matching(dir, ".tmp")
      |> should
      |> be_equal(Ok(0))
      |> or_fail_with("expected no files deleted in a missing directory")
    }),

    it("delete_files_matching reports a path that is a file", fn() {
      let path =
        "./test/tmp/file_api_test/not_a_dir_"
        <> int.to_string(unique_port())
        <> ".txt"
      let _ = write(path, "x")

      delete_files_matching(path, ".tmp")
      |> should
      |> be_equal(Error(FileSystemError(path, "enotdir")))
      |> or_fail_with("expected enotdir for a file path")
    }),

    it("delete_files_matching skips a matching name it cannot delete", fn() {
      let dir = "./test/tmp/file_api_test/skip_" <> int.to_string(unique_port())
      let _ = write(dir <> "/a.tmp", "a")
      let _ = write(dir <> "/sub.tmp/inner.txt", "a directory named sub.tmp")

      delete_files_matching(dir, ".tmp")
      |> should
      |> be_equal(Ok(1))
      |> or_fail_with("only a.tmp should be deleted, not the sub.tmp directory")
    }),

    it("write gives NoSpace for a file on a full disk", fn() {
      let #(path, result) = with_file_on_full_disk(write_hello)
      result
      |> should
      |> be_equal(Error(NoSpace(path)))
      |> or_fail_with("expected NoSpace for the file on the full disk")
    }),

    it("error_to_string formats NotFound", fn() {
      error_to_string(NotFound("/x"))
      |> should
      |> be_equal("File not found: /x")
      |> or_fail_with("NotFound formatting")
    }),

    it("error_to_string formats PermissionDenied", fn() {
      error_to_string(PermissionDenied("/x"))
      |> should
      |> be_equal("Permission denied: /x")
      |> or_fail_with("PermissionDenied formatting")
    }),

    it("error_to_string formats IsDirectory", fn() {
      error_to_string(IsDirectory("/x"))
      |> should
      |> be_equal("Is a directory: /x")
      |> or_fail_with("IsDirectory formatting")
    }),

    it("error_to_string formats NoSpace", fn() {
      error_to_string(NoSpace("/x"))
      |> should
      |> be_equal("No space left on device: /x")
      |> or_fail_with("NoSpace formatting")
    }),

    it("error_to_string formats FileSystemError", fn() {
      error_to_string(FileSystemError("/x", "enoent"))
      |> should
      |> be_equal("File error (enoent): /x")
      |> or_fail_with("FileSystemError formatting")
    }),
  ])
}

fn write_hello(path: String) -> Result(Nil, FileError) {
  write(path, "hello")
}

/// Call `run` with the path of a new file on a real device that has no
/// free space, and give the path and the result. Fails the test on a
/// system that has no such device.
@external(erlang, "dream_test_file_test_ffi", "with_file_on_full_disk")
fn with_file_on_full_disk(run: fn(String) -> a) -> #(String, a)
