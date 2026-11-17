import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{
  type Status, type TestResult, AssertionFailed, AssertionFailure, AssertionOk,
  Failed, Passed, SetupFailed, Skipped, Unit,
}
import dream_test/unit.{
  after_all, after_each, before_all, before_each, describe, group, it, skip,
  with_tags,
}
import gleam/list
import gleam/option.{None}

pub fn tests() {
  describe("dream_test/unit", [
    it("builds a suite and executes tests", fn() {
      let suite =
        describe("inner", [
          it("passes", fn() { Ok(AssertionOk) })
          |> with_tags(["smoke"]),
        ])

      let results = runner.new([suite]) |> runner.run()
      let assert [r] = results

      #(
        r.name,
        types.full_name(r.groups, r.name),
        r.status,
        r.tags,
        r.failures,
        r.kind,
      )
      |> should
      |> be_equal(#("passes", ["inner", "passes"], Passed, ["smoke"], [], Unit))
      |> or_fail_with("runner should execute a unit suite deterministically")
    }),

    it("propagates tags from groups to tests", fn() {
      let suite =
        describe("root", [
          group("g", [
            group("nested", [
              it("t", fn() { Ok(AssertionOk) })
              |> with_tags(["leaf"]),
            ])
            |> with_tags(["inner"]),
          ])
          |> with_tags(["group"]),
        ])

      let results = runner.new([suite]) |> runner.run()
      let assert [r] = results

      r.tags
      |> should
      |> be_equal(["group", "inner", "leaf"])
      |> or_fail_with("test tags should include group tags + test tags")
    }),

    it("returns Failed status when assertion fails", fn() {
      let suite =
        describe("root", [
          it("fails", fn() {
            Ok(
              AssertionFailed(AssertionFailure(
                operator: "x",
                message: "y",
                payload: None,
              )),
            )
          }),
        ])

      let results = runner.new([suite]) |> runner.run()
      let assert [r] = results

      r.status
      |> should
      |> be_equal(Failed)
      |> or_fail_with("failed assertion should produce Failed status")
    }),

    it("before_all failure gives SetupFailed and skips the test body", fn() {
      let suite =
        describe("root", [
          before_all(fn() { Error("nope") }),
          it("should not run", fn() { panic as "should not run" }),
        ])

      let results = runner.new([suite]) |> runner.run()
      let assert [r] = results

      #(r.status, r.failures)
      |> should
      |> be_equal(
        #(SetupFailed, [
          AssertionFailure(
            operator: "before_all",
            message: "nope",
            payload: None,
          ),
        ]),
      )
      |> or_fail_with(
        "before_all error should give SetupFailed without running the body",
      )
    }),

    it("skip reports the test as skipped without running it", fn() {
      let suite =
        describe("root", [skip("skipped", fn() { panic as "should not run" })])

      let results = runner.new([suite]) |> runner.run()
      let assert [r] = results

      #(r.name, r.status, r.failures)
      |> should
      |> be_equal(#("skipped", Skipped, []))
      |> or_fail_with("skip should give a Skipped result")
    }),

    it("before_all that succeeds lets the tests run", fn() {
      let suite =
        describe("root", [
          before_all(fn() { Ok(Nil) }),
          it("runs", fn() { Ok(AssertionOk) }),
        ])

      runner.new([suite])
      |> runner.run()
      |> statuses
      |> should
      |> be_equal([Passed])
      |> or_fail_with("the test should pass after a good before_all")
    }),

    it("before_each that succeeds lets the test run", fn() {
      let suite =
        describe("root", [
          before_each(fn() { Ok(Nil) }),
          it("runs", fn() { Ok(AssertionOk) }),
        ])

      runner.new([suite])
      |> runner.run()
      |> statuses
      |> should
      |> be_equal([Passed])
      |> or_fail_with("the test should pass after a good before_each")
    }),

    it("before_each failure fails the test with its message", fn() {
      let suite =
        describe("root", [
          before_each(fn() { Error("nope") }),
          it("should not run", fn() { panic as "should not run" }),
        ])

      let results = runner.new([suite]) |> runner.run()
      let assert [r] = results

      #(r.status, r.failures)
      |> should
      |> be_equal(
        #(SetupFailed, [
          AssertionFailure(
            operator: "before_each",
            message: "nope",
            payload: None,
          ),
        ]),
      )
      |> or_fail_with("before_each error should fail the test")
    }),

    it("after_each and after_all run after a passing test", fn() {
      let suite =
        describe("root", [
          after_each(fn() { Ok(Nil) }),
          after_all(fn() { Ok(Nil) }),
          it("runs", fn() { Ok(AssertionOk) }),
        ])

      runner.new([suite])
      |> runner.run()
      |> statuses
      |> should
      |> be_equal([Passed])
      |> or_fail_with("good teardown hooks should keep the test passing")
    }),

    it("with_tags leaves a hook node as it is", fn() {
      let hook = before_all(fn() { Ok(Nil) })

      with_tags(hook, ["tag"])
      |> should
      |> be_equal(hook)
      |> or_fail_with("with_tags should not change a hook node")
    }),
  ])
}

fn statuses(results: List(TestResult)) -> List(Status) {
  list.map(results, fn(result) { result.status })
}
