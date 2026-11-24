import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/parallel
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}

pub fn tests() -> TestSuite {
  describe("Example", [
    it("works", fn() {
      1 + 1
      |> should
      |> be_equal(2)
      |> or_fail_with("math should work")
    }),
  ])
}

pub fn db_tests() -> TestSuite {
  describe("Database", [
    it("connects", fn() { Ok(succeed()) }),
  ])
}

pub fn main() -> RunReport {
  let db_config =
    parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 60_000)

  runner.new([])
  |> runner.add_suites([tests()])
  |> runner.add_suites_with_config(db_config, [db_tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
