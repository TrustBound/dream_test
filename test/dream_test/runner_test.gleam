import dream_test/assertions/should.{
  be_false, be_ok, be_true, equal, have_length, or_fail_with, should,
}
import dream_test/runner
import dream_test/types.{
  AssertionOk, Failed, Passed, SetupFailed, TestResult, TimedOut, Unit,
}
import dream_test/unit.{
  after_all, describe, describe_with_hooks, group, hooks, it, with_tags,
}
import gleam/erlang/process.{
  new_selector, new_subject, select, selector_receive, send, spawn,
}
import gleam/list
import gleam/result
import gleam/string

pub fn tests() {
  describe("Runner", [
    it("runs a passing test and returns Passed", fn(_) {
      // Arrange
      let suite =
        describe("Suite", [
          it("passing", fn(_) { Ok(AssertionOk) }),
        ])

      // Act
      let results =
        runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

      let status_result = case results {
        [first] -> Ok(first.status)
        _ -> Error("Expected exactly 1 result")
      }

      // Assert
      status_result
      |> should()
      |> be_ok()
      |> equal(Passed)
      |> or_fail_with("Passing test should have Passed status")
    }),

    it("marks tests SetupFailed when before_all returns Error", fn(_) {
      // Arrange
      let suite =
        describe_with_hooks(
          "Suite",
          hooks(fn() { Error("Intentional before_all failure") }),
          [
            it("t1", fn(_) { Ok(AssertionOk) }),
            it("t2", fn(_) { Ok(AssertionOk) }),
          ],
        )

      // Act
      let results =
        runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

      let statuses_result = case results {
        [a, b] -> Ok([a.status, b.status])
        _ -> Error("Expected exactly 2 results")
      }

      // Assert
      statuses_result
      |> should()
      |> be_ok()
      |> equal([SetupFailed, SetupFailed])
      |> or_fail_with("Expected both tests SetupFailed")
    }),

    it(
      "after_all failure stops later suites and marks their tests SetupFailed",
      fn(_) {
        // Arrange: suite A fails in after_all
        let suite_a =
          describe_with_hooks("SuiteA", hooks(fn() { Ok(Nil) }), [
            after_all(fn(_nil) { Error("intentional after_all failure") }),
            it("a1 ran", fn(_nil) { Ok(AssertionOk) }),
          ])

        // Arrange: suite B must not run (if it runs, it will crash)
        let suite_b =
          describe("SuiteB", [
            it("must_not_run", fn(_) { panic as "suite B should not run" }),
          ])

        // Act
        let results =
          runner.new([suite_a, suite_b])
          |> runner.max_concurrency(1)
          |> runner.run()
        let status_result =
          list.find(results, fn(r) { r.name == "must_not_run" })
          |> result.map(fn(r) { r.status })

        // Assert
        status_result
        |> should()
        |> be_ok()
        |> equal(SetupFailed)
        |> or_fail_with(
          "must_not_run should be SetupFailed because suite B should not execute",
        )
      },
    ),

    group("has_failures", [
      it("returns true when any status indicates failure", fn(_) {
        let results = [
          TestResult(
            name: "test",
            full_name: ["test"],
            status: Passed,
            duration_ms: 0,
            tags: [],
            failures: [],
            kind: Unit,
          ),
          TestResult(
            name: "test",
            full_name: ["test"],
            status: Failed,
            duration_ms: 0,
            tags: [],
            failures: [],
            kind: Unit,
          ),
          TestResult(
            name: "test",
            full_name: ["test"],
            status: TimedOut,
            duration_ms: 0,
            tags: [],
            failures: [],
            kind: Unit,
          ),
        ]
        runner.has_failures(results)
        |> should()
        |> be_true()
        |> or_fail_with("Should detect failures")
      }),
      it("returns false when all statuses are non-failing", fn(_) {
        let results = [
          TestResult(
            name: "test",
            full_name: ["test"],
            status: Passed,
            duration_ms: 0,
            tags: [],
            failures: [],
            kind: Unit,
          ),
        ]
        runner.has_failures(results)
        |> should()
        |> be_false()
        |> or_fail_with("Should return false when no failures")
      }),
    ]),

    group("result filtering", [
      it("filters results by tag", fn(_) {
        let suite =
          describe("Feature", [
            it("test one", fn(_) { Ok(AssertionOk) }) |> with_tags(["unit"]),
            it("test two", fn(_) { Ok(AssertionOk) })
              |> with_tags(["integration"]),
            it("test three", fn(_) { Ok(AssertionOk) }) |> with_tags(["unit"]),
          ])

        let results =
          runner.new([suite])
          |> runner.max_concurrency(1)
          |> runner.filter_results(fn(r) { list.contains(r.tags, "unit") })
          |> runner.run()

        results
        |> should()
        |> have_length(2)
        |> or_fail_with("Should only return tests tagged 'unit'")
      }),

      it("filters results by test name", fn(_) {
        let suite =
          describe("Feature", [
            it("adds numbers", fn(_) { Ok(AssertionOk) }),
            it("subtracts numbers", fn(_) { Ok(AssertionOk) }),
            it("adds strings", fn(_) { Ok(AssertionOk) }),
          ])

        let results =
          runner.new([suite])
          |> runner.max_concurrency(1)
          |> runner.filter_results(fn(r) {
            case r.name {
              "adds numbers" -> True
              "adds strings" -> True
              _ -> False
            }
          })
          |> runner.run()

        results
        |> should()
        |> have_length(2)
        |> or_fail_with("Should filter by test name")
      }),
    ]),

    group("concurrency", [
      it(
        "starts two tests before either completes when max_concurrency=2",
        fn(_) {
          // Arrange
          let started = new_subject()
          let continue_t1 = new_subject()
          let continue_t2 = new_subject()

          let suite =
            describe("suite", [
              it("t1", fn(_) {
                send(started, "t1")
                let selector = new_selector() |> select(continue_t1)
                case selector_receive(selector, 5000) {
                  Ok(_) -> Ok(AssertionOk)
                  Error(Nil) -> Error("timeout waiting to continue t1")
                }
              }),
              it("t2", fn(_) {
                send(started, "t2")
                let selector = new_selector() |> select(continue_t2)
                case selector_receive(selector, 5000) {
                  Ok(_) -> Ok(AssertionOk)
                  Error(Nil) -> Error("timeout waiting to continue t2")
                }
              }),
            ])

          // Act
          let _pid =
            spawn(fn() {
              let _results =
                runner.new([suite]) |> runner.max_concurrency(2) |> runner.run()
              Nil
            })

          let selector = new_selector() |> select(started)
          use n1 <- result.try(case selector_receive(selector, 1000) {
            Ok(name) -> Ok(name)
            Error(Nil) -> Error("timeout waiting for started #1")
          })
          use n2 <- result.try(case selector_receive(selector, 1000) {
            Ok(name) -> Ok(name)
            Error(Nil) -> Error("timeout waiting for started #2")
          })

          send(continue_t1, Nil)
          send(continue_t2, Nil)

          // Assert
          list.sort([n1, n2], string.compare)
          |> should()
          |> equal(["t1", "t2"])
          |> or_fail_with(
            "Expected both tests to start before either completed",
          )
        },
      ),
    ]),
  ])
}
