import dream_test/file
import dream_test/matchers.{be_equal, be_ok, or_fail_with, should}
import dream_test/unit.{after_all, before_all, describe, it}
import gleam/result
import gleam/string

/// The file that the hooks make and remove.
pub const alice_file = "build/guide_hooks/alice.txt"

pub fn tests() {
  describe("User files", [
    before_all(write_alice),
    after_all(delete_alice),
    it("reads a user", fn() {
      file.read(alice_file)
      |> should
      |> be_ok()
      |> be_equal("Alice")
      |> or_fail_with("the file should hold Alice")
    }),
    it("reads the name in capitals", fn() {
      file.read(alice_file)
      |> result.map(string.uppercase)
      |> should
      |> be_ok()
      |> be_equal("ALICE")
      |> or_fail_with("the name should be ALICE in capitals")
    }),
  ])
}

fn write_alice() -> Result(Nil, String) {
  file.write(alice_file, "Alice")
  |> result.map_error(file.error_to_string)
}

fn delete_alice() -> Result(Nil, String) {
  file.delete(alice_file)
  |> result.map_error(file.error_to_string)
}
