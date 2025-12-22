import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() {
  describe("Example", [
    it("works", fn() {
      1 + 1
      |> should
      |> be_equal(2)
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
