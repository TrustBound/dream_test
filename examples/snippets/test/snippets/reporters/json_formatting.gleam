import dream_test/matchers.{match_snapshot, or_fail_with, should, succeed}
import dream_test/reporters/json
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/result
import gleam/string

fn example_suite() {
  describe("Example Suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

fn normalize_timestamp_ms(json: String) -> String {
  let #(before, after) =
    string.split_once(json, "\"timestamp_ms\":")
    |> result.unwrap(#("MISSING_TIMESTAMP_MS", ""))

  let #(_timestamp_digits, rest) =
    string.split_once(after, ",")
    |> result.unwrap(#("MISSING_TIMESTAMP_VALUE", after))

  before <> "\"timestamp_ms\":0," <> rest
}

pub fn tests() {
  describe("JSON formatting", [
    it("format_pretty returns JSON containing tests", fn() {
      let results = runner.new([example_suite()]) |> runner.run()
      let text = json.format_pretty(results)
      let normalized = normalize_timestamp_ms(text)

      normalized
      |> should
      |> match_snapshot("./test/snapshots/json_format_pretty.snap")
      |> or_fail_with("expected format_pretty snapshot match")
    }),
  ])
}
