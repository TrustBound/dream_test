import dream_test/coverage/markdown
import dream_test/coverage/report.{LineCoverage}

pub fn half_covered_table() -> String {
  report.new([
    report.file("src/a.gleam", [
      LineCoverage(line: 1, calls: 1),
      LineCoverage(line: 2, calls: 0),
    ]),
  ])
  |> markdown.render()
  // -> "## Coverage\n\n| File | Lines | Cover | Missing | Excluded |\n| --- | ---: | ---: | --- | --- |\n| src/a.gleam | 1/2 | 50.0% | 2 |  |\n| Total | 1/2 | 50.0% |  |  |\n"
}
