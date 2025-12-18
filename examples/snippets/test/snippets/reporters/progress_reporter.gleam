//// README: Progress reporter

import dream_test/assertions/should.{succeed}
import dream_test/reporter
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() {
  describe("Progress reporter", [
    it("passes", fn() { Ok(succeed()) }),
    it("also passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporter.progress(io.print))
  |> runner.exit_on_failure()
  |> runner.run()
}
