import dream_test/matchers.{match_snapshot_inspect, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import gleam/option.{Some}

pub fn some_one_matches_snapshot() -> Result(AssertionResult, String) {
  let path = "./build/doc_examples/match_snapshot_inspect_example.snap"
  Some(1)
  |> should
  |> match_snapshot_inspect(path)
  |> or_fail_with("expected inspect snapshot match")
}
