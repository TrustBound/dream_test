//// README: Tagging tests

import dream_test/assertions/should.{succeed}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it, with_tags}
import gleam/io

pub fn tests() {
  describe("Tagged tests", [
    it("fast", fn() { Ok(succeed()) })
      |> with_tags(["unit", "fast"]),
    it("slow", fn() { Ok(succeed()) })
      |> with_tags(["integration", "slow"]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
