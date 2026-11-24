import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/types as reporter_types
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}

pub fn reporter_name(reporter: reporter_types.ResultsReporter) -> String {
  case reporter {
    reporter_types.Bdd(_) -> "bdd"
    reporter_types.Json(_) -> "json"
    reporter_types.Custom(render: _) -> "custom"
  }
}

fn render_nothing(_report: RunReport) -> String {
  ""
}

pub fn tests() -> TestSuite {
  describe("ResultsReporter", [
    it("has the variant Custom", fn() {
      reporter_name(reporter_types.Custom(render: render_nothing))
      |> should
      |> be_equal("custom")
      |> or_fail_with("expected the name of the Custom variant")
    }),
  ])
}
