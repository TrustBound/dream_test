//// README: JSON reporter example

import dream_test/assertions/should.{succeed}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() {
  describe("JSON Reporter", [
    it("outputs JSON format", fn() {
      // The json.report function outputs machine-readable JSON
      // while bdd.report outputs human-readable text
      Ok(succeed())
    }),
    it("includes test metadata", fn() {
      // JSON output includes name, full_name, status, duration, tags
      Ok(succeed())
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporters.json(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
