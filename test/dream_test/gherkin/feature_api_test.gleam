import dream_test/gherkin/feature as gfeature
import dream_test/gherkin/steps
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should}
import dream_test/runner
import dream_test/types as test_types
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("dream_test/gherkin/feature", [
    it("inline feature() builds a runnable suite", fn() {
      // Arrange
      let registry =
        steps.new()
        |> steps.given("a thing", gherkin_step_ok)
        |> steps.then_("it works", gherkin_step_ok)

      let suite =
        gfeature.feature("Inline Feature", registry, [
          gfeature.scenario("Scenario 1", [
            gfeature.given("a thing"),
            gfeature.then("it works"),
          ]),
        ])

      // Act
      let results = runner.new([suite]) |> runner.run()

      // Assert
      case results {
        [
          test_types.TestResult(
            name: "Scenario 1",
            full_name: _,
            status: test_types.Passed,
            duration_ms: _,
            tags: _,
            failures: _,
            kind: _,
          ),
        ] -> Ok(test_types.AssertionOk)
        _ -> Ok(fail_with("unexpected results"))
      }
    }),

    it("with_tags adds scenario tags to the resulting test result", fn() {
      // Arrange
      let registry =
        steps.new()
        |> steps.given("a thing", gherkin_step_ok)

      let suite =
        gfeature.feature("Inline Tags", registry, [
          gfeature.scenario("Scenario 1", [gfeature.given("a thing")])
          |> gfeature.with_tags(["smoke"]),
        ])

      // Act
      let results = runner.new([suite]) |> runner.run()

      // Assert
      case results {
        [
          test_types.TestResult(
            name: _,
            full_name: _,
            status: _,
            duration_ms: _,
            tags: tags,
            failures: _,
            kind: _,
          ),
        ] ->
          tags
          |> should
          |> be_equal(["smoke"])
          |> or_fail_with("scenario tags should appear in result")
        _ -> Ok(fail_with("unexpected results"))
      }
    }),
  ])
}

fn gherkin_step_ok(
  _context: steps.StepContext,
) -> Result(test_types.AssertionResult, String) {
  Ok(test_types.AssertionOk)
}
