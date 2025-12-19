//// README: JSON formatting (post-run, string output)

import dream_test/assertions/should.{
  contain_string, or_fail_with, should, succeed,
}
import dream_test/reporters/json
import dream_test/runner
import dream_test/unit.{describe, it}

fn example_suite() {
  describe("Example Suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn tests() {
  describe("JSON formatting", [
    it("format_pretty returns JSON containing tests", fn() {
      let results = runner.new([example_suite()]) |> runner.run()
      let text = json.format_pretty(results)

      text
      |> should
      |> contain_string("\"tests\"")
      |> or_fail_with("Expected JSON report to include the tests array")
    }),
  ])
}
