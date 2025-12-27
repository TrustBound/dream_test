import dream_test/matchers.{succeed}
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Progress reporter", [
    it("passes", fn() { Ok(succeed()) }),
    it("also passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.exit_on_failure()
  |> runner.run()
}
