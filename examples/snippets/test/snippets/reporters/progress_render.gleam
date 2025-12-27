import dream_test/matchers.{match_snapshot, or_fail_with, should}
import dream_test/reporters/progress
import dream_test/reporters/types as reporter_types
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Progress reporter: render", [
    it("renders a fixed-width progress bar line", fn() {
      progress.render(30, reporter_types.RunStarted(total: 10))
      |> should
      |> match_snapshot("./test/snapshots/progress_render_run_started.snap")
      |> or_fail_with("expected render output snapshot match")
    }),
  ])
}
