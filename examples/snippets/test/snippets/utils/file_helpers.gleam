import dream_test/file.{NotFound, delete, error_to_string, read, write}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process.{unique_port}
import dream_test/unit.{describe, it}
import gleam/int

fn tmp_path() {
  "./test/tmp/file_helpers_" <> int.to_string(unique_port()) <> ".txt"
}

pub fn tests() {
  describe("File helpers", [
    it("write + read roundtrip", fn() {
      let path = tmp_path()
      let _ = write(path, "hello")

      read(path)
      |> should
      |> be_equal(Ok("hello"))
      |> or_fail_with("expected to read back written content")
    }),

    it("delete removes a file", fn() {
      let path = tmp_path()
      let _ = write(path, "hello")
      let _ = delete(path)

      read(path)
      |> should
      |> be_equal(Error(NotFound(path)))
      |> or_fail_with("expected deleted file to be NotFound")
    }),

    it("error_to_string formats NotFound", fn() {
      error_to_string(NotFound("/x"))
      |> should
      |> be_equal("File not found: /x")
      |> or_fail_with("expected NotFound formatting")
    }),
  ])
}
