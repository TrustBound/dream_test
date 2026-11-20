import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/summary
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/string

pub fn render_my_report(report: RunReport) -> String {
  // `summary.count` counts the tests by status. It counts the teardown
  // hooks that failed apart from the setups whose process stopped.
  let counts = summary.count(report)

  string.concat([
    "MyReport: ",
    int.to_string(counts.run),
    " total; ",
    int.to_string(counts.passed),
    " passed; ",
    int.to_string(counts.failed + counts.timed_out + counts.setup_failed),
    " failed; ",
    int.to_string(counts.teardown_failed),
    " teardown failed; ",
    int.to_string(counts.setup_stopped),
    " setup stopped\n",
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([reporter_types.Custom(render_my_report)])
  |> runner.exit_on_failure()
  |> runner.run()
}

fn example_suite() {
  describe("Example Suite", [
    it("passes", fn() { Ok(succeed()) }),
    it("also passes", fn() { Ok(succeed()) }),
  ])
}

pub fn tests() {
  describe("Custom post-run reporter", [
    it("the runner writes the report at the end of the run", fn() {
      let written = process.new_subject()
      let _report =
        runner.new([example_suite()])
        |> runner.results_reporters([reporter_types.Custom(render_my_report)])
        |> runner.output(runner.Output(
          out: send_to(written),
          error: send_to(written),
        ))
        |> runner.run()
      process.receive(written, 0)
      |> should
      |> be_equal(Ok(
        "MyReport: 2 total; 2 passed; 0 failed; 0 teardown failed; 0 setup stopped\n",
      ))
      |> or_fail_with("expected the runner to write the custom report")
    }),
    it("renders the counts of a run", fn() {
      runner.new([example_suite()])
      |> runner.silent()
      |> runner.run()
      |> render_my_report
      |> should
      |> be_equal(
        "MyReport: 2 total; 2 passed; 0 failed; 0 teardown failed; 0 setup stopped\n",
      )
      |> or_fail_with("expected the report line for two passing tests")
    }),
    it("counts stopped setups apart from failed teardown hooks", fn() {
      types.run_report(
        tests: [],
        teardown_failures: [
          types.TeardownFailure(
            hook: types.AfterAllHook,
            groups: ["Example Suite"],
            message: "no cleanup",
          ),
          types.SetupStopped(
            setup: types.BeforeAllHook,
            groups: ["Example Suite"],
            reason: "killed",
            not_run: [],
          ),
        ],
        reporter_crashes: [],
      )
      |> render_my_report
      |> should
      |> be_equal(
        "MyReport: 0 total; 0 passed; 0 failed; 1 teardown failed; 1 setup stopped\n",
      )
      |> or_fail_with("expected one failed hook and one stopped setup")
    }),
  ])
}

/// A writer that sends each text to `subject`.
fn send_to(subject: Subject(String)) -> fn(String) -> Nil {
  fn(text) { process.send(subject, text) }
}
