import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, group, it, with_tags}

pub fn tests() {
  describe("Tagged tests", [
    // Tag a whole group (all tests inside inherit these tags)
    group("integration", [
      it("slow path", fn() { Ok(succeed()) }),
      it("another slow path", fn() { Ok(succeed()) }),
    ])
      |> with_tags(["integration", "slow"]),

    // Or tag a single test
    it("smoke", fn() { Ok(succeed()) })
      |> with_tags(["smoke"]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
