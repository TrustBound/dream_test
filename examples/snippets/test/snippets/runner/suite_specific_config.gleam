import dream_test/matchers.{succeed}
import dream_test/parallel
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}

fn unit_tests() {
  describe("Unit suite", [
    it("is fast", fn() { Ok(succeed()) }),
  ])
}

fn db_tests() {
  describe("DB suite (sequential)", [
    it("pretend db test", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  let db_config =
    parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 60_000)

  runner.new([])
  |> runner.add_suites([unit_tests()])
  |> runner.add_suites_with_config(db_config, [db_tests()])
  |> runner.max_concurrency(8)
  |> runner.default_timeout_ms(10_000)
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
