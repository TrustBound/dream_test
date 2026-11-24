import dream_test/parallel
import dream_test/reporters/bdd
import dream_test/runner
import envoy
import outputs_tests
import recorded_http/alerts_tests
import recorded_http/forecast_tests
import recorded_queries/tasks_tests

pub fn main() {
  runner.new([forecast_tests.tests(), alerts_tests.tests()])
  |> runner.add_suites_with_config(one_at_a_time(), [tasks_tests.tests()])
  |> runner.add_suites(output_checks())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

/// The task tests share one table, so they run one at a time, in order.
fn one_at_a_time() -> parallel.ParallelConfig {
  parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 10_000)
}

/// The output checks compare the reports of a playback run with the
/// outputs that the guides show, so a record run leaves them out.
fn output_checks() {
  case envoy.get("RECORDER_MODE") {
    Ok("record") -> []
    _ -> [outputs_tests.tests(), outputs_tests.live_tests()]
  }
}
