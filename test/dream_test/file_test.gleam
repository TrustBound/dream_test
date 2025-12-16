import dream_test/assertions/should.{
  be_error, be_ok, contain_string, equal, or_fail_with, should,
}
import dream_test/file
import dream_test/unit.{before_each, describe, group, it}

pub fn tests() {
  describe("file", [
    group("read", [
      it("returns Ok for existing file", fn(_) {
        let path = "test/fixtures/file/readable/example.txt"
        file.read(path)
        |> should()
        |> be_ok()
        |> or_fail_with("read should return Ok for existing file")
      }),
      it("returns file content", fn(_) {
        let path = "test/fixtures/file/readable/example.txt"
        file.read(path)
        |> should()
        |> equal(Ok("hello world\n"))
        |> or_fail_with("read should return file content")
      }),
      it("returns Ok with empty string for empty file", fn(_) {
        let path = "test/fixtures/file/readable/empty.txt"
        file.read(path)
        |> should()
        |> equal(Ok(""))
        |> or_fail_with("read should return empty string for empty file")
      }),
      it("returns NotFound error for missing file", fn(_) {
        let path = "test/fixtures/file/readable/does_not_exist.txt"
        file.read(path)
        |> should()
        |> equal(Error(file.NotFound(path)))
        |> or_fail_with("read should return NotFound for missing file")
      }),
    ]),

    group("write", [
      it("returns Ok when writing", fn(_) {
        let path = "test/fixtures/file/temp/write_ok.txt"
        let content = "test content"
        file.write(path, content)
        |> should()
        |> be_ok()
        |> or_fail_with("write should return Ok")
      }),
      it("creates file with correct content", fn(_) {
        let path = "test/fixtures/file/temp/write_content.txt"
        let content = "test content"
        let _ = file.write(path, content)
        file.read(path)
        |> should()
        |> equal(Ok(content))
        |> or_fail_with("written file should contain correct content")
      }),
      it("creates parent directories", fn(_) {
        let path = "test/fixtures/file/temp/nested/deep/created.txt"
        let content = "nested content"
        file.write(path, content)
        |> should()
        |> be_ok()
        |> or_fail_with("write should create parent directories")
      }),
      it("overwrites existing file", fn(_) {
        let path = "test/fixtures/file/temp/write_overwrite.txt"
        let _ = file.write(path, "old content")
        let new_content = "new content"
        let _ = file.write(path, new_content)
        file.read(path)
        |> should()
        |> equal(Ok(new_content))
        |> or_fail_with("write should overwrite existing content")
      }),
    ]),

    group("delete", [
      before_each(fn(_) {
        let _ =
          file.write(
            "test/fixtures/file/deletable/to_delete.txt",
            "delete me\n",
          )
        Ok(Nil)
      }),
      it("returns Ok for existing file", fn(_) {
        let path = "test/fixtures/file/deletable/to_delete.txt"
        file.delete(path)
        |> should()
        |> be_ok()
        |> or_fail_with("delete should return Ok for existing file")
      }),
      it("removes the file", fn(_) {
        let path = "test/fixtures/file/deletable/to_delete.txt"
        let _ = file.delete(path)
        file.read(path)
        |> should()
        |> be_error()
        |> or_fail_with("file should not exist after delete")
      }),
      it("returns Ok for non-existent file", fn(_) {
        let path = "test/fixtures/file/deletable/does_not_exist.txt"
        file.delete(path)
        |> should()
        |> be_ok()
        |> or_fail_with("delete should be idempotent for missing file")
      }),
    ]),

    group("delete_files_matching", [
      it("returns count of deleted files", fn(_) {
        let dir = "test/fixtures/file/temp/match_count"
        let _ = file.write(dir <> "/a.snap", "a")
        let _ = file.write(dir <> "/b.snap", "b")
        file.delete_files_matching(dir, ".snap")
        |> should()
        |> equal(Ok(2))
        |> or_fail_with("should return count of deleted files")
      }),
      it("removes matching files", fn(_) {
        let dir = "test/fixtures/file/temp/match_remove"
        let _ = file.write(dir <> "/target.snap", "target")
        let _ = file.delete_files_matching(dir, ".snap")
        file.read(dir <> "/target.snap")
        |> should()
        |> be_error()
        |> or_fail_with("matching files should be deleted")
      }),
      it("does not remove non-matching files", fn(_) {
        let dir = "test/fixtures/file/temp/match_keep"
        let _ = file.write(dir <> "/delete.snap", "delete")
        let _ = file.write(dir <> "/keep.txt", "keep")
        let _ = file.delete_files_matching(dir, ".snap")
        file.read(dir <> "/keep.txt")
        |> should()
        |> be_ok()
        |> or_fail_with("non-matching files should remain")
      }),
      it("returns 0 when no files match", fn(_) {
        let dir = "test/fixtures/file/temp/match_none"
        file.delete_files_matching(dir, ".snap")
        |> should()
        |> equal(Ok(0))
        |> or_fail_with("should return 0 when nothing matches")
      }),
    ]),

    group("error_to_string", [
      it("formats NotFound error", fn(_) {
        let error = file.NotFound("/path/to/file.txt")
        file.error_to_string(error)
        |> should()
        |> contain_string("not found")
        |> or_fail_with("NotFound error should mention 'not found'")
      }),
      it("includes path in error message", fn(_) {
        let error = file.NotFound("/path/to/file.txt")
        file.error_to_string(error)
        |> should()
        |> contain_string("/path/to/file.txt")
        |> or_fail_with("error message should include the path")
      }),
    ]),
  ])
}
