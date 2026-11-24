import dream_test/discover
import dream_test/matchers.{succeed}
import dream_test/parallel
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/unit.{describe, it}
import snippets/guides/writing_tests_cart

pub fn main() {
  runner.new([writing_tests_cart.tests()])
  |> runner.add_suites(check_suites())
  |> runner.add_suites_with_config(database_config(), [database_tests()])
  |> runner.max_concurrency(8)
  |> runner.default_timeout_ms(10_000)
  |> runner.results_reporters([bdd.new() |> bdd.summary_only()])
  |> runner.exit_on_failure()
  |> runner.run()
}

fn check_suites() {
  discover.tests("snippets/guides/**_check.gleam")
  |> discover.to_suites()
}

/// The database tests share one schema, so they run one at a time, and a
/// slow query gets a minute.
fn database_config() -> parallel.ParallelConfig {
  parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 60_000)
}

fn database_tests() {
  describe("Database", [
    it("creates a user", fn() { Ok(succeed()) }),
    it("deletes a user", fn() { Ok(succeed()) }),
  ])
}
