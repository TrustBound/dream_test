import dream_test/file
import dream_test/matchers.{be_equal, match_snapshot, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/list
import gleam/result

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

fn write_bdd_report_to_file(text: String) {
  case file.write("test/tmp/bdd_report.txt", text) {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}

fn first_result(results: List(a)) -> Result(a, String) {
  case list.first(results) {
    Ok(value) -> Ok(value)
    Error(_) -> Error("expected at least one test result")
  }
}

pub fn tests() {
  describe("BDD reporter module", [
    it("report writes output", fn() {
      bdd.report([passing_result()], write_bdd_report_to_file)

      use text <- result.try(
        file.read("test/tmp/bdd_report.txt")
        |> result.map_error(file.error_to_string),
      )

      text
      |> should
      |> match_snapshot("./test/snapshots/bdd_report_file_output.snap")
      |> or_fail_with("expected report output snapshot match")
    }),
    it("format_incremental returns the next describe path", fn() {
      use first <- result.try(first_result([passing_result()]))

      let bdd.FormatIncrementalResult(text: _text, new_path: new_path) =
        bdd.format_incremental(first, [])

      new_path
      |> should
      |> be_equal(["Example Suite"])
      |> or_fail_with("expected new_path to be the describe path")
    }),
  ])
}
