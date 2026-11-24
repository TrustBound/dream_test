import dream_test/matchers.{match_snapshot, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn hello_matches_snapshot() -> Result(AssertionResult, String) {
  let path = "./build/doc_examples/match_snapshot_example.snap"
  "hello"
  |> should
  |> match_snapshot(path)
  |> or_fail_with("expected snapshot match")
}
