//// README: Skipping tests

import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporter/bdd.{report}
import dream_test/runner.{run_all}
import dream_test/unit.{describe, it, skip, to_test_cases}
import gleam/io
import snippets.{add}

pub fn tests() {
  describe("Skipping tests", [
    it("runs normally", fn() {
      add(2, 3)
      |> should()
      |> equal(5)
      |> or_fail_with("2 + 3 should equal 5")
    }),
    skip("not implemented yet", fn() {
      // This test is skipped - the body is preserved but not executed
      add(100, 200)
      |> should()
      |> equal(300)
      |> or_fail_with("Should add large numbers")
    }),
    it("also runs normally", fn() {
      add(0, 0)
      |> should()
      |> equal(0)
      |> or_fail_with("0 + 0 should equal 0")
    }),
  ])
}

pub fn main() {
  to_test_cases("skipping_tests", tests())
  |> run_all()
  |> report(io.print)
}
