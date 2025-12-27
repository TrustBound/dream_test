import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/string

pub fn tests() {
  describe("String utilities", [
    it("trims whitespace", fn() {
      "  hello  "
      |> string.trim()
      |> should
      |> be_equal("hello")
      |> or_fail_with("Should remove surrounding whitespace")
    }),
    it("finds substrings", fn() {
      "hello world"
      |> string.contains("world")
      |> should
      |> be_equal(True)
      |> or_fail_with("Should find 'world' in string")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
