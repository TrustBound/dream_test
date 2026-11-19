import dream_test/concurrency_probe.{type Probe}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{type Status, Passed}
import dream_test/unit.{describe, it}
import gleam/list

pub fn tests() {
  describe("dream_test/parallel", [
    it("runs tests in parallel and keeps deterministic ordering", fn() {
      // In the parallel run, no test goes on until all four run at the same
      // time, so the run completes only when the runner runs four tests at
      // the same time. The 2 second timeout is a safety limit: when the
      // runner runs the tests one by one, the first test times out instead
      // of the whole test. The serial run must never run two tests at the
      // same time.
      let parallel_probe = concurrency_probe.start(4)
      let par_results =
        runner.new([probe_suite(parallel_probe)])
        |> runner.max_concurrency(4)
        |> runner.default_timeout_ms(2000)
        |> runner.run()
        |> types.report_tests

      let serial_probe = concurrency_probe.start(1)
      let serial_results =
        runner.new([probe_suite(serial_probe)])
        |> runner.max_concurrency(1)
        |> runner.run()
        |> types.report_tests

      #(
        list.map(par_results, fn(r) { r.name }),
        statuses(par_results),
        concurrency_probe.peak(parallel_probe),
        statuses(serial_results),
        concurrency_probe.peak(serial_probe),
      )
      |> should
      |> be_equal(#(
        ["t1", "t2", "t3", "t4"],
        [Passed, Passed, Passed, Passed],
        4,
        [Passed, Passed, Passed, Passed],
        1,
      ))
      |> or_fail_with(
        "expected four tests at the same time in a deterministic order, and one at a time in the serial run",
      )
    }),
  ])
}

fn probe_suite(probe: Probe) {
  describe("p", [
    it("t1", fn() { concurrency_probe.run(probe) }),
    it("t2", fn() { concurrency_probe.run(probe) }),
    it("t3", fn() { concurrency_probe.run(probe) }),
    it("t4", fn() { concurrency_probe.run(probe) }),
  ])
}

fn statuses(results: List(types.TestResult)) -> List(Status) {
  list.map(results, fn(r) { r.status })
}
