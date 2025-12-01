import dream_test/assertions/should.{
  be_error, be_ok, equal, or_fail_with, should,
}
import dream_test/reporter/bdd.{report}
import dream_test/runner.{run_all}
import dream_test/unit.{describe, it, to_test_cases}
import gleam/io
import string_app

pub fn tests() {
  describe("String utilities", [
    it("shouts a message", fn() {
      string_app.shout("hello")
      |> should()
      |> equal("HELLO!")
      |> or_fail_with("Should convert to uppercase with !")
    }),

    it("whispers a message", fn() {
      string_app.whisper("HELLO")
      |> should()
      |> equal("hello")
      |> or_fail_with("Should convert to lowercase")
    }),

    it("cleans up whitespace", fn() {
      string_app.clean("  hello  ")
      |> should()
      |> equal("hello")
      |> or_fail_with("Should trim whitespace")
    }),

    describe("greet", [
      it("greets by name", fn() {
        string_app.greet("Alice")
        |> should()
        |> be_ok()
        |> equal("Hello, Alice!")
        |> or_fail_with("Should greet by name")
      }),

      it("rejects empty names", fn() {
        string_app.greet("")
        |> should()
        |> be_error()
        |> or_fail_with("Should reject empty name")
      }),

      it("trims name before greeting", fn() {
        string_app.greet("  Bob  ")
        |> should()
        |> be_ok()
        |> equal("Hello, Bob!")
        |> or_fail_with("Should trim name before greeting")
      }),
    ]),
  ])
}

pub fn main() {
  let test_tree = tests()
  let test_cases = to_test_cases("string_app_test", test_tree)
  let results = run_all(test_cases)
  report(results, io.print)
}
