import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{
  AssertionFailed, AssertionFailure, AssertionOk, Failed, Passed, Unit,
}
import dream_test/unit.{before_all, describe, group, it, with_tags}
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

      #(r.name, r.full_name, r.status, r.tags, r.failures, r.kind)
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

    it("before_all failure fails tests and skips the test body", fn() {
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
        #(Failed, [
          AssertionFailure(
            operator: "before_all",
            message: "nope",
            payload: None,
          ),
        ]),
      )
      |> or_fail_with(
        "before_all error should fail the test without running the body",
      )
    }),
  ])
}
