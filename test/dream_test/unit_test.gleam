import dream_test/assertions/should.{
  be_empty, equal, fail_with, or_fail_with, should,
}
import dream_test/runner
import dream_test/types.{AssertionOk, Skipped}
import dream_test/unit.{describe, group, it, skip, with_tags}

pub fn tests() {
  describe("Unit DSL", [
    group("suite structure", [
      it("sets result name from it label", fn(_) {
        let suite =
          describe("Math", [
            it("adds numbers", fn(_) { Ok(AssertionOk) }),
            it("subtracts numbers", fn(_) { Ok(AssertionOk) }),
          ])

        let results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        case results {
          [first, ..] ->
            first.name
            |> should()
            |> equal("adds numbers")
            |> or_fail_with("First test name should match it label")

          _ -> Ok(fail_with("Expected at least one test result"))
        }
      }),

      it("sets full_name from describe + it", fn(_) {
        let suite =
          describe("Math", [
            it("adds numbers", fn(_) { Ok(AssertionOk) }),
          ])

        let results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        case results {
          [first] ->
            first.full_name
            |> should()
            |> equal(["Math", "adds numbers"])
            |> or_fail_with("full_name should include describe and it")

          _ -> Ok(fail_with("Expected exactly one test result"))
        }
      }),
    ]),

    group("with_tags", [
      it("sets tags on a test", fn(_) {
        let suite =
          describe("Feature", [
            it("tagged test", fn(_) { Ok(AssertionOk) })
            |> with_tags(["unit", "fast"]),
          ])

        let results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        case results {
          [first] ->
            first.tags
            |> should()
            |> equal(["unit", "fast"])
            |> or_fail_with("Tags should be set on test result")

          _ -> Ok(fail_with("Expected exactly one test result"))
        }
      }),

      it("replaces existing tags", fn(_) {
        let suite =
          describe("Feature", [
            it("test", fn(_) { Ok(AssertionOk) })
            |> with_tags(["first"])
            |> with_tags(["second"]),
          ])

        let results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        case results {
          [first] ->
            first.tags
            |> should()
            |> equal(["second"])
            |> or_fail_with("Second with_tags should replace first")

          _ -> Ok(fail_with("Expected exactly one test result"))
        }
      }),

      it("leaves tests without tags empty", fn(_) {
        let suite =
          describe("Feature", [
            it("untagged test", fn(_) { Ok(AssertionOk) }),
          ])

        let results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        case results {
          [first] ->
            first.tags
            |> should()
            |> be_empty()
            |> or_fail_with("Untagged test should have empty tags")

          _ -> Ok(fail_with("Expected exactly one test result"))
        }
      }),
    ]),

    group("skip", [
      it("produces Skipped status", fn(_) {
        let suite =
          describe("Feature", [
            skip("not ready yet", fn(_) { Ok(AssertionOk) }),
          ])

        let results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        case results {
          [first] ->
            first.status
            |> should()
            |> equal(Skipped)
            |> or_fail_with("skip should produce Skipped status")

          _ -> Ok(fail_with("Expected exactly one test result"))
        }
      }),

      it("preserves the test name", fn(_) {
        let suite =
          describe("Feature", [
            skip("work in progress", fn(_) { Ok(AssertionOk) }),
          ])

        let results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        case results {
          [first] ->
            first.name
            |> should()
            |> equal("work in progress")
            |> or_fail_with("skip should preserve the test name")

          _ -> Ok(fail_with("Expected exactly one test result"))
        }
      }),
    ]),
  ])
}
