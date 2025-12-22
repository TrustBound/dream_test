import dream_test/matchers.{match_snapshot_inspect, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{Some}

pub fn tests() {
  describe("matchers.match_snapshot_inspect", [
    it("snapshots any value by using string.inspect", fn() {
      let path = "./test/tmp/match_snapshot_inspect_example.snap"
      Some(1)
      |> should
      |> match_snapshot_inspect(path)
      |> or_fail_with("expected inspect snapshot match")
    }),
  ])
}
