import dream_test/coverage.{
  type LineCoverage, CoverageReport, FileCoverage, LineCoverage,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/coverage as coverage_reporter
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}

pub fn tests() {
  describe("dream_test/reporters/coverage", [
    it("renders a row per file, a total and the LCOV path", fn() {
      CoverageReport(
        files: [
          FileCoverage(source_path: "src/app/cart.gleam", lines: [
            LineCoverage(line: 3, calls: 2),
            LineCoverage(line: 4, calls: 0),
            LineCoverage(line: 9, calls: 1),
          ]),
          FileCoverage(source_path: "src/app/types.gleam", lines: []),
        ],
        lcov_path: Some("build/coverage/lcov.info"),
      )
      |> coverage_reporter.render()
      |> should
      |> be_equal(
        "\nCoverage\n"
        <> "File                 Lines  Cover\n"
        <> "src/app/cart.gleam   2/3    66.6%\n"
        <> "src/app/types.gleam  0/0    -\n"
        <> "Total                2/3    66.6%\n"
        <> "LCOV: build/coverage/lcov.info\n",
      )
      |> or_fail_with("expected the coverage table")
    }),
    it("rounds down so a file is 100.0% only when every line ran", fn() {
      let lines = [
        LineCoverage(line: 1, calls: 1),
        ..repeat_hit_lines(2, 1000, [LineCoverage(line: 1001, calls: 0)])
      ]
      CoverageReport(
        files: [FileCoverage(source_path: "a.gleam", lines: lines)],
        lcov_path: None,
      )
      |> coverage_reporter.render()
      |> should
      |> be_equal(
        "\nCoverage\n"
        <> "File     Lines      Cover\n"
        <> "a.gleam  1000/1001  99.9%\n"
        <> "Total    1000/1001  99.9%\n",
      )
      |> or_fail_with("expected 99.9%, not 100.0%")
    }),
  ])
}

fn repeat_hit_lines(from: Int, to: Int, accumulated: List(LineCoverage)) {
  case from > to {
    True -> accumulated
    False ->
      repeat_hit_lines(from, to - 1, [
        LineCoverage(line: to, calls: 1),
        ..accumulated
      ])
  }
}
