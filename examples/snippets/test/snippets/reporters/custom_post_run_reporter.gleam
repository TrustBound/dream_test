import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/parallel
import dream_test/reporters/summary
import dream_test/runner
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/io
import gleam/string

pub fn render_my_report(report: RunReport) -> String {
  // `summary.count` counts the tests by status. It counts the tear-down
  // hooks that failed apart from the set-ups whose process stopped.
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
    " tear-down failed; ",
    int.to_string(counts.setup_stopped),
    " set-up stopped\n",
  ])
}

pub fn main() {
  let report = runner.new([tests()]) |> runner.run()
  io.print(render_my_report(report))
}

fn example_suite() {
  describe("Example Suite", [
    it("passes", fn() { Ok(succeed()) }),
    it("also passes", fn() { Ok(succeed()) }),
  ])
}

pub fn tests() {
  describe("Custom post-run reporter", [
    it("renders the counts of a run", fn() {
      parallel.run_root_parallel(parallel.default_config(), example_suite())
      |> render_my_report
      |> should
      |> be_equal(
        "MyReport: 2 total; 2 passed; 0 failed; 0 tear-down failed; 0 set-up stopped\n",
      )
      |> or_fail_with("expected the report line for two passing tests")
    }),
    it("counts stopped set-ups apart from failed tear-down hooks", fn() {
      types.run_report(tests: [], teardown_failures: [
        types.TeardownFailure(
          hook: types.AfterAllHook,
          groups: ["Example Suite"],
          message: "no cleanup",
        ),
        types.SetupStopped(
          set_up: types.BeforeAllHook,
          groups: ["Example Suite"],
          reason: "killed",
          not_run: [],
        ),
      ])
      |> render_my_report
      |> should
      |> be_equal(
        "MyReport: 0 total; 0 passed; 0 failed; 1 tear-down failed; 1 set-up stopped\n",
      )
      |> or_fail_with("expected one failed hook and one stopped set-up")
    }),
  ])
}
