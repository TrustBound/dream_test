import dream_test/concurrency_probe.{type Probe}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/parallel
import dream_test/runner
import dream_test/types.{AssertionOk, Passed, TimedOut}
import dream_test/unit.{describe, it, with_tags}
import gleam/erlang/process
import gleam/list
import gleam/result

fn is_smoke(info: runner.TestInfo) -> Bool {
  list.contains(info.tags, "smoke")
}

pub fn tests() {
  describe("dream_test/runner", [
    it("runs suites and returns results", fn() {
      let suite = describe("s", [it("t", fn() { Ok(AssertionOk) })])
      let results =
        runner.new([suite])
        |> runner.run()
        |> types.report_tests
      let assert [r] = results
      r.status |> should |> be_equal(Passed) |> or_fail_with("test should pass")
    }),

    it("filters which tests execute with filter_tests", fn() {
      let suite =
        describe("s", [
          it("a", fn() { Ok(AssertionOk) }) |> with_tags(["smoke"]),
          it("b", fn() { panic as "should not run" }),
        ])

      let results =
        runner.new([suite])
        |> runner.filter_tests(is_smoke)
        |> runner.run()
        |> types.report_tests

      let assert [r] = results
      r.name
      |> should
      |> be_equal("a")
      |> or_fail_with("should run only the smoke test")
    }),

    it("can add suites with a per-suite execution config override", fn() {
      let ok_suite =
        describe("ok", [
          it("passes", fn() { Ok(AssertionOk) }),
        ])

      let slow_suite =
        describe("slow", [
          it("times out", fn() {
            process.sleep_forever()
            Ok(AssertionOk)
          }),
        ])

      let timeout_config =
        parallel.ParallelConfig(max_concurrency: 4, default_timeout_ms: 10)

      let results =
        runner.new([])
        |> runner.default_timeout_ms(500)
        |> runner.add_suites([ok_suite])
        |> runner.add_suites_with_config(timeout_config, [slow_suite])
        |> runner.run()
        |> types.report_tests

      let assert [r1, r2] = results

      use _ <- result.try(
        types.full_name(r1.groups, r1.name)
        |> should
        |> be_equal(["ok", "passes"])
        |> or_fail_with("expected first suite to run first"),
      )

      use _ <- result.try(
        r1.status
        |> should
        |> be_equal(Passed)
        |> or_fail_with("expected ok suite test to pass"),
      )

      r2.status
      |> should
      |> be_equal(TimedOut)
      |> or_fail_with(
        "expected slow suite test to time out via override config",
      )
    }),

    it(
      "per-suite max_concurrency override can mix sequential and parallel suites in one run",
      fn() {
        // A probe with a barrier of 4 lets no test go on until four tests
        // of its suite run at the same time. Without the override, both
        // suites run four tests at the same time. With the override, the
        // sequential suite runs one test at a time while the other suite
        // still runs four at the same time. The 2 second timeouts are
        // safety limits that a passing run never reaches.
        let parallel_a = concurrency_probe.start(4)
        let parallel_b = concurrency_probe.start(4)
        let parallel_statuses =
          runner.new([
            probe_suite("parallel_suite", parallel_a),
            probe_suite("sequential_suite", parallel_b),
          ])
          |> runner.max_concurrency(4)
          |> runner.default_timeout_ms(2000)
          |> runner.run()
          |> types.report_tests
          |> list.map(fn(r) { r.status })

        let seq_config =
          parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 2000)

        let mixed_a = concurrency_probe.start(4)
        let mixed_b = concurrency_probe.start(1)
        let mixed_statuses =
          runner.new([])
          |> runner.add_suites([probe_suite("parallel_suite", mixed_a)])
          |> runner.add_suites_with_config(seq_config, [
            probe_suite("sequential_suite", mixed_b),
          ])
          |> runner.max_concurrency(4)
          |> runner.default_timeout_ms(2000)
          |> runner.run()
          |> types.report_tests
          |> list.map(fn(r) { r.status })

        #(
          parallel_statuses,
          concurrency_probe.peak(parallel_a),
          concurrency_probe.peak(parallel_b),
          mixed_statuses,
          concurrency_probe.peak(mixed_a),
          concurrency_probe.peak(mixed_b),
        )
        |> should
        |> be_equal(#(
          list.repeat(Passed, 8),
          4,
          4,
          list.repeat(Passed, 8),
          4,
          1,
        ))
        |> or_fail_with(
          "expected the sequential suite to run one test at a time only with its override",
        )
      },
    ),
  ])
}

fn probe_suite(name: String, probe: Probe) {
  describe(name, [
    it("t1", fn() { concurrency_probe.run(probe) }),
    it("t2", fn() { concurrency_probe.run(probe) }),
    it("t3", fn() { concurrency_probe.run(probe) }),
    it("t4", fn() { concurrency_probe.run(probe) }),
  ])
}
