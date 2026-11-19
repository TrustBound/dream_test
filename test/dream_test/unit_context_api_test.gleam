import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{AssertionOk, Passed, Skipped}
import dream_test/unit_context.{before_all, describe, group, it, skip, with_tags}

pub fn tests() {
  describe("dream_test/unit_context", Nil, [
    it("runs a context-aware test body", fn(_ctx: Nil) { Ok(AssertionOk) }),

    it("propagates tags to tests", fn(_ctx: Nil) {
      let suite =
        describe("root", Nil, [
          group("g", [
            it("t", fn(_ctx2: Nil) { Ok(AssertionOk) }) |> with_tags(["leaf"]),
          ])
          |> with_tags(["group"]),
        ])

      let results =
        runner.new([suite])
        |> runner.run()
        |> types.report_tests
      let assert [r] = results

      #(r.status, r.tags)
      |> should
      |> be_equal(#(Passed, ["group", "leaf"]))
      |> or_fail_with("status and tag propagation should match")
    }),

    it("allows before_all to transform context", fn(_ctx: Nil) {
      let suite =
        describe("root", 0, [
          before_all(fn(n: Int) { Ok(n + 1) }),
          it("sees updated context", fn(n: Int) {
            n |> should |> be_equal(1) |> or_fail_with("context should be 1")
          }),
        ])

      let results =
        runner.new([suite])
        |> runner.run()
        |> types.report_tests
      let assert [r] = results

      r.status |> should |> be_equal(Passed) |> or_fail_with("test should pass")
    }),

    it("skip reports the test as skipped without running it", fn(_ctx: Nil) {
      let suite =
        describe("root", 0, [
          skip("skipped", fn(_n: Int) { panic as "should not run" }),
        ])

      let results =
        runner.new([suite])
        |> runner.run()
        |> types.report_tests
      let assert [r] = results

      #(r.name, r.status, r.failures)
      |> should
      |> be_equal(#("skipped", Skipped, []))
      |> or_fail_with("skip should give a Skipped result")
    }),

    it("with_tags leaves a hook node as it is", fn(_ctx: Nil) {
      let hook = before_all(fn(n: Int) { Ok(n) })

      with_tags(hook, ["tag"])
      |> should
      |> be_equal(hook)
      |> or_fail_with("with_tags should not change a hook node")
    }),
  ])
}
