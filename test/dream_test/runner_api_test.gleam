import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{AssertionOk, Passed}
import dream_test/unit.{describe, it, with_tags}
import gleam/list

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
  ])
}
