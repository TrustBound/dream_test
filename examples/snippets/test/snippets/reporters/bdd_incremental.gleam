import dream_test/matchers.{match_snapshot, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/types
import dream_test/unit.{describe, it}

fn passing_result() -> types.TestResult {
  types.TestResult(
    name: "passes",
    full_name: ["Example Suite", "passes"],
    status: types.Passed,
    duration_ms: 0,
    tags: [],
    failures: [],
    kind: types.Unit,
  )
}

fn incremental_parts_text(parts: bdd.FormatIncrementalPartsResult) -> String {
  case parts {
    bdd.FormatIncrementalPartsResult(headers: headers, test_line: test_line, ..) ->
      headers <> test_line
  }
}

pub fn tests() {
  describe("BDD incremental formatting", [
    it("format_incremental_with_test_indent returns a formatted line", fn() {
      let result = passing_result()
      let bdd.FormatIncrementalResult(text: text, new_path: _new_path) =
        bdd.format_incremental_with_test_indent(result, [], 0)

      text
      |> should
      |> match_snapshot(
        "./test/snapshots/bdd_format_incremental_with_test_indent.snap",
      )
      |> or_fail_with("expected incremental output snapshot match")
    }),
    it(
      "format_incremental_parts_with_test_indent returns headers + test_line",
      fn() {
        let result = passing_result()
        let text =
          bdd.format_incremental_parts_with_test_indent(result, [], 0)
          |> incremental_parts_text

        text
        |> should
        |> match_snapshot(
          "./test/snapshots/bdd_format_incremental_parts_with_test_indent.snap",
        )
        |> or_fail_with("expected incremental parts snapshot match")
      },
    ),
    it("format_summary_only returns a summary line", fn() {
      let summary = bdd.format_summary_only([passing_result()])

      summary
      |> should
      |> match_snapshot("./test/snapshots/bdd_format_summary_only.snap")
      |> or_fail_with("expected summary snapshot match")
    }),
  ])
}
