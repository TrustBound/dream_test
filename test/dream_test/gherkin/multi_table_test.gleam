//// Test that multiple steps with tables work correctly

import dream_test/gherkin/parser
import dream_test/gherkin/types as gtypes
import dream_test/matchers.{fail_with}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import gleam/option.{Some}
import gleam/result

pub fn tests() {
  describe("Multiple tables in steps", [
    it("parser correctly parses multiple tables", fn() {
      let content =
        "Feature: Multi Table\n"
        <> "\n"
        <> "  Scenario: Two tables\n"
        <> "    Given the first table:\n"
        <> "      | A | B |\n"
        <> "      | 1 | 2 |\n"
        <> "    When the second table:\n"
        <> "      | X | Y |\n"
        <> "      | 3 | 4 |\n"

      let validation_result = {
        use feature <- result.try(parse_content(content))
        use scenario <- result.try(get_single_scenario(feature))
        use #(step1, step2) <- result.try(get_two_steps(scenario))
        use table1 <- result.try(get_step_table(step1, "Step 1"))
        use table2 <- result.try(get_step_table(step2, "Step 2"))
        use _ <- result.try(verify_table(table1, expected_table1(), "First"))
        use _ <- result.try(verify_table(table2, expected_table2(), "Second"))
        Ok(Nil)
      }

      case validation_result {
        Ok(_) -> Ok(AssertionOk)
        Error(message) -> Ok(fail_with(message))
      }
    }),
  ])
}

fn parse_content(content: String) -> Result(gtypes.Feature, String) {
  parser.parse_string(content)
}

fn get_single_scenario(
  feature: gtypes.Feature,
) -> Result(gtypes.Scenario, String) {
  case feature.scenarios {
    [scenario] -> Ok(scenario)
    _ -> Error("Expected 1 scenario")
  }
}

fn get_two_steps(
  scenario: gtypes.Scenario,
) -> Result(#(gtypes.Step, gtypes.Step), String) {
  case scenario {
    gtypes.Scenario(_, _, steps) -> extract_two_steps(steps)
    gtypes.ScenarioOutline(_, _, _, _) ->
      Error("Expected Scenario, got ScenarioOutline")
  }
}

fn extract_two_steps(
  steps: List(gtypes.Step),
) -> Result(#(gtypes.Step, gtypes.Step), String) {
  case steps {
    [step1, step2] -> Ok(#(step1, step2))
    _ -> Error("Expected 2 steps")
  }
}

fn get_step_table(
  step: gtypes.Step,
  step_name: String,
) -> Result(List(List(String)), String) {
  case step.argument {
    Some(gtypes.DataTable(rows)) -> Ok(rows)
    _ -> Error(step_name <> " has no table")
  }
}

fn verify_table(
  actual: List(List(String)),
  expected: List(List(String)),
  table_name: String,
) -> Result(Nil, String) {
  case actual == expected {
    True -> Ok(Nil)
    False -> Error(table_name <> " table has wrong content")
  }
}

fn expected_table1() -> List(List(String)) {
  [["A", "B"], ["1", "2"]]
}

fn expected_table2() -> List(List(String)) {
  [["X", "Y"], ["3", "4"]]
}
