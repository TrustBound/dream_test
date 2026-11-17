import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/io
import gleam/string

pub fn tests() {
  describe("Coverage markers", [
    it("converts the old record format", fn() {
      convert_legacy("a;b")
      |> should
      |> be_equal("a,b")
      |> or_fail_with("semicolons should become commas")
    }),
  ])
}

pub fn log(message: String) -> Nil {
  // coverage:ignore
  io.println(message)
}

// coverage:ignore-start debug helpers
pub fn dump(value: a) -> a {
  echo value
}

// coverage:ignore-end

// coverage:ignore-function only old callers use this
/// Converts the old record format.
pub fn convert_legacy(record: String) -> String {
  string.replace(record, ";", ",")
}
