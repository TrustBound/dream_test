import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{before_all, describe, it}

fn connect_to_database() {
  Ok(Nil)
}

pub fn tests() {
  describe("Handles failures", [
    before_all(fn() {
      case connect_to_database() {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error("Database connection failed: " <> e)
      }
    }),
    // If before_all fails, these tests are marked SetupFailed (not run)
    it("test1", fn() { Ok(succeed()) }),
    it("test2", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
