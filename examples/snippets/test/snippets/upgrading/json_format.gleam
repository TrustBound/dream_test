import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/json
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/string

fn example_suite() {
  describe("Example Suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  let report = runner.new([example_suite()]) |> runner.run()
  json.format(report)
}

pub fn tests() {
  describe("JSON format", [
    it("writes schema version 2.0", fn() {
      main()
      |> string.contains("\"version\":\"2.0\"")
      |> should
      |> be_equal(True)
      |> or_fail_with("expected the JSON schema version 2.0")
    }),
  ])
}
