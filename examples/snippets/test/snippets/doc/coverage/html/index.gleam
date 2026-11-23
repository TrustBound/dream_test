import dream_test/coverage/html
import dream_test/coverage/report.{LineCoverage}

pub fn index_page() -> String {
  report.new([
    report.file("src/a.gleam", [LineCoverage(line: 1, calls: 1)]),
  ])
  |> html.index()
  // -> "<!DOCTYPE html>\n<html lang=\"en\">\n..."
}
