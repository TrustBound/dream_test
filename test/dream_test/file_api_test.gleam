import dream_test/file.{
  FileSystemError, IsDirectory, NoSpace, NotFound, PermissionDenied, delete,
  delete_files_matching, error_to_string, read, write,
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
