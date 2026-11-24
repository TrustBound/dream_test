import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it, with_tags}

pub fn tests() -> TestSuite {
  describe("Tagged tests", [
    it("fast", fn() { Ok(succeed()) })
      |> with_tags(["unit", "fast"]),
    it("slow", fn() { Ok(succeed()) })
      |> with_tags(["integration", "slow"]),
  ])
}

pub fn main() -> RunReport {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
