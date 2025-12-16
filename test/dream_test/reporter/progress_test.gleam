import dream_test/assertions/should.{be_true, equal, or_fail_with, should}
import dream_test/reporter/progress
import dream_test/reporter/types as reporter_types
import dream_test/types.{Passed, TestResult, Unit}
import dream_test/unit.{describe, group, it}
import gleam/list
import gleam/string

pub fn tests() {
  describe("Progress Reporter", [
    group("render", [
      it("pads to the target width", fn(_) {
        let line = progress.render(40, reporter_types.RunStarted(total: 10))
        string.to_graphemes(line)
        |> list.length
        |> should()
        |> equal(40)
        |> or_fail_with("render should pad to the requested width")
      }),
      it("clamps width to at least 20 columns", fn(_) {
        let line = progress.render(10, reporter_types.RunStarted(total: 1))
        string.to_graphemes(line)
        |> list.length
        |> should()
        |> equal(20)
        |> or_fail_with("render should clamp width to >= 20 graphemes")
      }),
      it("includes the completed/total counter", fn(_) {
        let result =
          TestResult(
            name: "adds",
            full_name: ["Math", "adds"],
            status: Passed,
            duration_ms: 0,
            tags: [],
            failures: [],
            kind: Unit,
          )
        let line =
          progress.render(
            60,
            reporter_types.TestFinished(completed: 3, total: 12, result: result),
          )
        string.contains(line, "3/12")
        |> should()
        |> be_true()
        |> or_fail_with("progress line should include the completed counter")
      }),
      it("pads/truncates by grapheme count for unicode names", fn(_) {
        let result =
          TestResult(
            name: "ユニコード",
            full_name: [
              "Root",
              "ユニコード",
              "ユニコード",
              "ユニコード",
              "ユニコード",
            ],
            status: Passed,
            duration_ms: 0,
            tags: [],
            failures: [],
            kind: Unit,
          )
        let line =
          progress.render(
            30,
            reporter_types.TestFinished(completed: 1, total: 1, result: result),
          )

        string.to_graphemes(line)
        |> list.length
        |> should()
        |> equal(30)
        |> or_fail_with(
          "render should pad/truncate to exact width by graphemes",
        )
      }),
      it("renders a final line for RunFinished", fn(_) {
        let line =
          progress.render(
            50,
            reporter_types.RunFinished(completed: 5, total: 5),
          )
        string.contains(line, "5/5")
        |> should()
        |> be_true()
        |> or_fail_with("RunFinished line should include the final counter")
      }),
    ]),
  ])
}
