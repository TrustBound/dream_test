import dream_test/coverage/html
import dream_test/coverage/report.{LineCoverage}

pub fn source_page_of_file() -> String {
  report.file("src/a.gleam", [LineCoverage(line: 1, calls: 2)])
  |> html.source_page(source: "pub fn a() { 1 }\n")
  // -> "<!DOCTYPE html>\n<html lang=\"en\">\n..."
}
