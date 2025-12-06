import dream_test/assertions/should.{
  be_error, be_ok, contain_string, equal, or_fail_with, should, succeed,
}
import dream_test/file
import dream_test/unit.{before_each, describe, it}

pub fn tests() {
  describe("file", [
    describe("read", [
      it("returns Ok for existing file", fn() {
        // Arrange
        let path = "test/fixtures/file/readable/example.txt"

        // Act
        let result = file.read(path)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("read should return Ok for existing file")
      }),
      it("returns file content", fn() {
        // Arrange
        let path = "test/fixtures/file/readable/example.txt"

        // Act
        let result = file.read(path)

        // Assert
        result
        |> should()
        |> equal(Ok("hello world\n"))
        |> or_fail_with("read should return file content")
      }),
      it("returns Ok with empty string for empty file", fn() {
        // Arrange
        let path = "test/fixtures/file/readable/empty.txt"

        // Act
        let result = file.read(path)

        // Assert
        result
        |> should()
        |> equal(Ok(""))
        |> or_fail_with("read should return empty string for empty file")
      }),
      it("returns NotFound error for missing file", fn() {
        // Arrange
        let path = "test/fixtures/file/readable/does_not_exist.txt"

        // Act
        let result = file.read(path)

        // Assert
        result
        |> should()
        |> equal(Error(file.NotFound(path)))
        |> or_fail_with("read should return NotFound for missing file")
      }),
    ]),
    describe("write", [
      it("returns Ok when writing", fn() {
        // Arrange - unique path for this test
        let path = "test/fixtures/file/temp/write_ok.txt"
        let content = "test content"

        // Act
        let result = file.write(path, content)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("write should return Ok")
      }),
      it("creates file with correct content", fn() {
        // Arrange - unique path for this test
        let path = "test/fixtures/file/temp/write_content.txt"
        let content = "test content"

        // Act
        let _ = file.write(path, content)
        let result = file.read(path)

        // Assert
        result
        |> should()
        |> equal(Ok(content))
        |> or_fail_with("written file should contain correct content")
      }),
      it("creates parent directories", fn() {
        // Arrange - unique nested path for this test
        let path = "test/fixtures/file/temp/nested/deep/created.txt"
        let content = "nested content"

        // Act
        let result = file.write(path, content)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("write should create parent directories")
      }),
      it("overwrites existing file", fn() {
        // Arrange - unique path for this test
        let path = "test/fixtures/file/temp/write_overwrite.txt"
        let _ = file.write(path, "old content")
        let new_content = "new content"

        // Act
        let _ = file.write(path, new_content)
        let result = file.read(path)

        // Assert
        result
        |> should()
        |> equal(Ok(new_content))
        |> or_fail_with("write should overwrite existing content")
      }),
    ]),
    describe("delete", [
      before_each(fn() {
        // Restore deletable fixture before each test
        let _ =
          file.write(
            "test/fixtures/file/deletable/to_delete.txt",
            "delete me\n",
          )
        succeed()
      }),
      it("returns Ok for existing file", fn() {
        // Arrange
        let path = "test/fixtures/file/deletable/to_delete.txt"

        // Act
        let result = file.delete(path)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("delete should return Ok for existing file")
      }),
      it("removes the file", fn() {
        // Arrange
        let path = "test/fixtures/file/deletable/to_delete.txt"

        // Act
        let _ = file.delete(path)
        let result = file.read(path)

        // Assert
        result
        |> should()
        |> be_error()
        |> or_fail_with("file should not exist after delete")
      }),
      it("returns Ok for non-existent file", fn() {
        // Arrange
        let path = "test/fixtures/file/deletable/does_not_exist.txt"

        // Act
        let result = file.delete(path)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with(
          "delete should return Ok for non-existent file (idempotent)",
        )
      }),
    ]),
    describe("delete_files_matching", [
      it("returns count of deleted files", fn() {
        // Arrange - create files in unique dir for this test
        let dir = "test/fixtures/file/temp/match_count"
        let _ = file.write(dir <> "/a.snap", "a")
        let _ = file.write(dir <> "/b.snap", "b")

        // Act
        let result = file.delete_files_matching(dir, ".snap")

        // Assert
        result
        |> should()
        |> equal(Ok(2))
        |> or_fail_with("should return count of deleted files")
      }),
      it("removes matching files", fn() {
        // Arrange - create files in unique dir for this test
        let dir = "test/fixtures/file/temp/match_remove"
        let _ = file.write(dir <> "/target.snap", "target")

        // Act
        let _ = file.delete_files_matching(dir, ".snap")
        let result = file.read(dir <> "/target.snap")

        // Assert
        result
        |> should()
        |> be_error()
        |> or_fail_with("matching files should be deleted")
      }),
      it("does not remove non-matching files", fn() {
        // Arrange - create files in unique dir for this test
        let dir = "test/fixtures/file/temp/match_keep"
        let _ = file.write(dir <> "/delete.snap", "delete")
        let _ = file.write(dir <> "/keep.txt", "keep")

        // Act
        let _ = file.delete_files_matching(dir, ".snap")
        let result = file.read(dir <> "/keep.txt")

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("non-matching files should not be deleted")
      }),
      it("returns 0 when no files match", fn() {
        // Arrange - use empty temp dir
        let dir = "test/fixtures/file/temp/match_empty"
        let _ = file.write(dir <> "/keep.txt", "keep")

        // Act
        let result = file.delete_files_matching(dir, ".snap")

        // Assert
        result
        |> should()
        |> equal(Ok(0))
        |> or_fail_with("should return 0 when no files match")
      }),
    ]),
    describe("error_to_string", [
      it("formats NotFound error", fn() {
        // Arrange
        let error = file.NotFound("/path/to/file.txt")

        // Act
        let result = file.error_to_string(error)

        // Assert
        result
        |> should()
        |> contain_string("not found")
        |> or_fail_with("NotFound error should mention 'not found'")
      }),
      it("includes path in error message", fn() {
        // Arrange
        let error = file.NotFound("/path/to/file.txt")

        // Act
        let result = file.error_to_string(error)

        // Assert
        result
        |> should()
        |> contain_string("/path/to/file.txt")
        |> or_fail_with("error message should include the path")
      }),
      it("formats PermissionDenied error", fn() {
        // Arrange
        let error = file.PermissionDenied("/secret/file.txt")

        // Act
        let result = file.error_to_string(error)

        // Assert
        result
        |> should()
        |> contain_string("ermission")
        |> or_fail_with("PermissionDenied should mention permission")
      }),
      it("formats IsDirectory error", fn() {
        // Arrange
        let error = file.IsDirectory("/some/dir")

        // Act
        let result = file.error_to_string(error)

        // Assert
        result
        |> should()
        |> contain_string("directory")
        |> or_fail_with("IsDirectory should mention directory")
      }),
      it("formats FileSystemError with reason", fn() {
        // Arrange
        let error = file.FileSystemError("/path", "custom_reason")

        // Act
        let result = file.error_to_string(error)

        // Assert
        result
        |> should()
        |> contain_string("custom_reason")
        |> or_fail_with("FileSystemError should include the reason")
      }),
    ]),
  ])
}
