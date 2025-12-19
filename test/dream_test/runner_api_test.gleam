import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{type TestResult, AssertionOk, Passed}
import dream_test/unit.{describe, it, with_tags}
import gleam/list

fn is_smoke(result: TestResult) -> Bool {
  list.contains(result.tags, "smoke")
}

pub fn tests() {
  describe("dream_test/runner", [
    it("runs suites and returns results", fn() {
      let suite = describe("s", [it("t", fn() { Ok(AssertionOk) })])
      let results = runner.new([suite]) |> runner.run()
      let assert [r] = results
      r.status |> should |> equal(Passed) |> or_fail_with("test should pass")
    }),

    it("filters returned results with filter_results", fn() {
      let suite =
        describe("s", [
          it("a", fn() { Ok(AssertionOk) }) |> with_tags(["smoke"]),
          it("b", fn() { Ok(AssertionOk) }),
        ])

      let results =
        runner.new([suite])
        |> runner.filter_results(is_smoke)
        |> runner.run()

      let assert [r] = results
      r.name
      |> should
      |> equal("a")
      |> or_fail_with("should keep only smoke test")
    }),
  ])
}
