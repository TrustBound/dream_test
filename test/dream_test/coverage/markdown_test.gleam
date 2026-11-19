import dream_test/coverage/markdown
import dream_test/coverage/report.{LineCoverage}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}
import gleam/string

fn full_report() {
  report.new([
    report.file("src/app/cart.gleam", [
      LineCoverage(line: 3, calls: 2),
      LineCoverage(line: 4, calls: 0),
      LineCoverage(line: 5, calls: 0),
      LineCoverage(line: 9, calls: 0),
    ])
      |> report.add_ignored_ranges([
        report.ignored_range(
          first_line: 40,
          last_line: 44,
          reason: Some("debug | only"),
        ),
        report.ignored_range(first_line: 71, last_line: 71, reason: None),
      ]),
    report.file("src/app/types.gleam", []),
    report.file("src/a_b|c\\d.gleam", [LineCoverage(line: 1, calls: 1)]),
  ])
  |> report.add_excluded_files([
    report.excluded_file(
      source_path: "src/app/generated/db.gleam",
      pattern: "src/app/generated/**",
      reason: Some("`generated` <code> [x] #1 ~y"),
    ),
  ])
}

fn full_markdown() {
  string.concat([
    "## Coverage\n\n",
    "| File | Lines | Cover | Missing | Excluded |\n",
    "| --- | ---: | ---: | --- | --- |\n",
    "| src/app/cart.gleam | 1/4 | 25.0% | 4-5, 9 | 40-44 (debug \\| only), 71 |\n",
    "| src/app/types.gleam | 0/0 | - |  |  |\n",
    "| src/a\\_b\\|c\\\\d.gleam | 1/1 | 100.0% |  |  |\n",
    "| src/app/generated/db.gleam |  |  |  | excluded: matches src/app/generated/\\*\\* (\\`generated\\` \\<code\\> \\[x\\] \\#1 \\~y) |\n",
    "| Total | 2/5 | 40.0% |  |  |\n",
    "\nExcluded: 1 file, 6 lines in 1 file\n",
  ])
}

fn empty_markdown() {
  string.concat([
    "## Coverage\n\n",
    "| File | Lines | Cover | Missing | Excluded |\n",
    "| --- | ---: | ---: | --- | --- |\n",
    "| Total | 0/0 | - |  |  |\n",
  ])
}

pub fn tests() {
  describe("dream_test/coverage/markdown", [
    it("renders every file, excluded file, the total and the summary", fn() {
      markdown.render(report: full_report())
      |> should
      |> be_equal(full_markdown())
      |> or_fail_with("expected the full Markdown table")
    }),
    it("renders an empty report with only the total", fn() {
      markdown.render(report: report.new([]))
      |> should
      |> be_equal(empty_markdown())
      |> or_fail_with("expected the empty Markdown table")
    }),
  ])
}
