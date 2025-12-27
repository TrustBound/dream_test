import dream_test/matchers.{fail_with, succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}
import snippets.{divide}

pub fn tests() {
  describe("Explicit failures", [
    it("succeeds explicitly when division works", fn() {
      let result = divide(10, 2)
      Ok(case result {
        Ok(_) -> succeed()
        Error(_) -> fail_with("Should have succeeded")
      })
    }),
    it("fails explicitly when expecting an error", fn() {
      let result = divide(10, 0)
      Ok(case result {
        Ok(_) -> fail_with("Should have returned an error")
        Error(_) -> succeed()
      })
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
