//// README: Minimal test runner for `gleam test`
////
//// In your own project, you typically create a `test/<something>_test.gleam`
//// module with a `pub fn main()` that runs your suites.

import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() {
  describe("Example", [
    it("works", fn() {
      1 + 1
      |> should()
      |> equal(2)
      |> or_fail_with("math should work")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
