import dream_test/matchers.{succeed}
import dream_test/reporters/json
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}

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
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([json.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
