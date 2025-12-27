import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner.{type TestInfo}
import dream_test/unit.{describe, it, with_tags}
import gleam/list

pub fn tests() {
  describe("Filtering tests", [
    it("smoke", fn() {
      1 + 1
      |> should
      |> be_equal(2)
      |> or_fail_with("math should work")
    })
      |> with_tags(["smoke"]),
    it("slow", fn() { Ok(succeed()) })
      |> with_tags(["slow"]),
  ])
}

pub fn only_smoke(info: TestInfo) -> Bool {
  list.contains(info.tags, "smoke")
}

pub fn main() {
  runner.new([tests()])
  |> runner.filter_tests(only_smoke)
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
