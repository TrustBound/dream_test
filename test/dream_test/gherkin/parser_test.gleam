import dream_test/assertions/should.{
  be_true, equal, fail_with, or_fail_with, should,
}
import dream_test/gherkin/parser.{parse_string}
import dream_test/gherkin/types as gherkin_types
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, group, it}

pub fn tests() {
  describe("Gherkin Parser", [
    group("parse_string", [
      it("parses minimal feature name", fn(_) {
        let content = "Feature: Shopping Cart\n"
        case parse_string(content) {
          Ok(feature) ->
            feature.name
            |> should()
            |> equal("Shopping Cart")
            |> or_fail_with("Feature name should parse")
          Error(msg) -> Ok(fail_with("Parse failed: " <> msg))
        }
      }),

      it("returns error for empty content", fn(_) {
        case parse_string("") {
          Error(_) -> Ok(AssertionOk)
          Ok(_) -> Ok(fail_with("Should return error for empty content"))
        }
      }),

      it("returns error without Feature keyword", fn(_) {
        case parse_string("Scenario: Something") {
          Error(_) -> Ok(AssertionOk)
          Ok(_) -> Ok(fail_with("Should return error without Feature keyword"))
        }
      }),

      it("parses feature tags", fn(_) {
        let content = "@smoke @regression\nFeature: Tagged Feature\n"
        case parse_string(content) {
          Ok(feature) ->
            feature.tags
            |> should()
            |> equal(["smoke", "regression"])
            |> or_fail_with("Feature tags should parse")
          Error(msg) -> Ok(fail_with("Parse failed: " <> msg))
        }
      }),

      it("parses a scenario", fn(_) {
        let content = "Feature: F\n\nScenario: S1\n  Given something\n"

        case parse_string(content) {
          Ok(feature) -> {
            let ok = case feature.scenarios {
              [gherkin_types.Scenario(name: name, ..), ..] -> name == "S1"
              _ -> False
            }
            ok
            |> should()
            |> be_true()
            |> or_fail_with("Should parse scenario name")
          }
          Error(msg) -> Ok(fail_with("Parse failed: " <> msg))
        }
      }),
    ]),
  ])
}
