import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import snippets/doc/file/delete
import snippets/doc/file/delete_files_matching
import snippets/doc/file/error_to_string
import snippets/doc/file/read
import snippets/doc/file/write

pub fn tests() {
  describe("Doc examples: file", [
    it("not_found_names_the_path passes", fn() {
      // Act
      let result = error_to_string.not_found_names_the_path()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected not_found_names_the_path to pass")
    }),
    it("written_content_reads_back passes", fn() {
      // Act
      let result = read.written_content_reads_back()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected written_content_reads_back to pass")
    }),
    it("write_a_greeting gives the expected value", fn() {
      // Act
      let result = write.write_a_greeting()

      // Assert
      result
      |> should
      |> be_equal(Ok(Nil))
      |> or_fail_with("expected write_a_greeting to give the expected value")
    }),
    it("deleted_file_is_not_found passes", fn() {
      // Act
      let result = delete.deleted_file_is_not_found()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected deleted_file_is_not_found to pass")
    }),
    it("deletes_two_snapshots passes", fn() {
      // Act
      let result = delete_files_matching.deletes_two_snapshots()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected deletes_two_snapshots to pass")
    }),
  ])
}
