import dream_test/matchers.{succeed}
import dream_test/parallel
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}

pub fn unit_suite() -> TestSuite {
  describe("Unit", [
    it("adds", fn() { Ok(succeed()) }),
  ])
}

pub fn db_suite() -> TestSuite {
  describe("Database", [
    it("connects", fn() { Ok(succeed()) }),
  ])
}

pub fn run_database_suite_alone() -> RunReport {
  let db_config =
    parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 60_000)

  runner.new([])
  |> runner.add_suites([unit_suite()])
  |> runner.add_suites_with_config(db_config, [db_suite()])
  |> runner.max_concurrency(50)
  |> runner.default_timeout_ms(5000)
  |> runner.run()
}
