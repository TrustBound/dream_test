import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/parallel
import dream_test/runner
import dream_test/timing
import dream_test/types.{
  AssertionFailed, AssertionFailure, AssertionOk, Passed, TimedOut,
}
import dream_test/unit.{describe, it, with_tags}
import gleam/erlang/process
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string

fn is_smoke(info: runner.TestInfo) -> Bool {
  list.contains(info.tags, "smoke")
}

pub fn tests() {
  describe("dream_test/runner", [
    it("runs suites and returns results", fn() {
      let suite = describe("s", [it("t", fn() { Ok(AssertionOk) })])
      let results = runner.new([suite]) |> runner.run()
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

      let assert [r] = results
      r.name
      |> should
      |> be_equal("a")
      |> or_fail_with("should run only the smoke test")
    }),

    it("can add suites with a per-suite execution config override", fn() {
      let ok_suite =
        describe("ok", [
          it("passes", fn() {
            process.sleep(20)
            Ok(AssertionOk)
          }),
        ])

      let slow_suite =
        describe("slow", [
          it("times out", fn() {
            process.sleep(200)
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

      let assert [r1, r2] = results

      use _ <- result.try(
        r1.full_name
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
        let suite_a =
          describe("parallel_suite", [
            it("t1", fn() {
              process.sleep(100)
              Ok(AssertionOk)
            }),
            it("t2", fn() {
              process.sleep(100)
              Ok(AssertionOk)
            }),
            it("t3", fn() {
              process.sleep(100)
              Ok(AssertionOk)
            }),
            it("t4", fn() {
              process.sleep(100)
              Ok(AssertionOk)
            }),
          ])

        let suite_b =
          describe("sequential_suite", [
            it("t1", fn() {
              process.sleep(100)
              Ok(AssertionOk)
            }),
            it("t2", fn() {
              process.sleep(100)
              Ok(AssertionOk)
            }),
            it("t3", fn() {
              process.sleep(100)
              Ok(AssertionOk)
            }),
            it("t4", fn() {
              process.sleep(100)
              Ok(AssertionOk)
            }),
          ])

        let t_parallel_start = timing.now_ms()
        let _ =
          runner.new([suite_a, suite_b])
          |> runner.max_concurrency(4)
          |> runner.run()
        let t_parallel = timing.now_ms() - t_parallel_start

        let seq_config =
          parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 5000)

        let t_mixed_start = timing.now_ms()
        let _ =
          runner.new([])
          |> runner.add_suites([suite_a])
          |> runner.add_suites_with_config(seq_config, [suite_b])
          |> runner.max_concurrency(4)
          |> runner.run()
        let t_mixed = timing.now_ms() - t_mixed_start

        case t_mixed > t_parallel + 200 {
          True -> Ok(AssertionOk)
          False ->
            Ok(
              AssertionFailed(AssertionFailure(
                operator: "mixed_concurrency",
                message: "expected mixed run to be slower than fully-parallel run, parallel="
                  <> string.inspect(t_parallel)
                  <> "ms mixed="
                  <> string.inspect(t_mixed)
                  <> "ms",
                payload: None,
              )),
            )
        }
      },
    ),
  ])
}
