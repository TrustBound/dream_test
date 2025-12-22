import dream_test/matchers.{match_snapshot, or_fail_with, should}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("matchers.match_snapshot", [
    it("compares a string against a snapshot file", fn() {
      let path = "./test/tmp/match_snapshot_example.snap"
      "hello"
      |> should
      |> match_snapshot(path)
      |> or_fail_with("expected snapshot match")
    }),
  ])
}
