//// README: Quick Start example

import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporter/api as reporter
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io
import gleam/string

pub fn tests() {
  describe("String utilities", [
    it("trims whitespace", fn(_) {
      "  hello  "
      |> string.trim()
      |> should()
      |> equal("hello")
      |> or_fail_with("Should remove surrounding whitespace")
    }),
    it("finds substrings", fn(_) {
      "hello world"
      |> string.contains("world")
      |> should()
      |> equal(True)
      |> or_fail_with("Should find 'world' in string")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporter.bdd(io.print, True))
  |> runner.run()
  |> runner.exit_results_on_failure
}
