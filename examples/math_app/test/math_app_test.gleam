import math_app
import gleam/io
import dream_test/unit.{describe, it, to_test_cases}
import dream_test/assertions/should.{or_fail_with}
import dream_test/runner.{run_all}
import dream_test/reporter/bdd.{report}

/// Example tests showing how a user of dream_test might test a simple app.
///
/// These tests are not part of dream_test's own bootstrap; they live in the
/// example project and depend on dream_test as a library.
pub fn tests() {
  describe("MathApp", [
    it("adds numbers", fn() {
      math_app.add(1, 2)
      |> should.equal(3)
      |> or_fail_with("1 + 2 should equal 3")
    }),

    it("parses integers from valid strings", fn() {
      math_app.parse_int("123")
      |> should.equal(Ok(123))
      |> or_fail_with("Should parse 123 from string")
    }),

    it("returns an error for invalid strings", fn() {
      math_app.parse_int("abc")
      |> should.equal(Error("Could not parse integer from string: abc"))
      |> or_fail_with("Should return an error for invalid input")
    }),
  ])
}

pub fn main() {
  let test_tree = tests()
  let test_cases = to_test_cases("math_app_test", test_tree)
  let results = run_all(test_cases)
  report(results, io.print)
}
