import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{AssertionOk, Passed}
import dream_test/unit_context.{before_all, describe, group, it, with_tags}

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

      let results = runner.new([suite]) |> runner.run()
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

      let results = runner.new([suite]) |> runner.run()
      let assert [r] = results

      r.status |> should |> be_equal(Passed) |> or_fail_with("test should pass")
    }),
  ])
}
