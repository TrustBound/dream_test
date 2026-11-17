//// Coverage as Cobertura XML.
////
//// GitLab, Jenkins and Azure DevOps read Cobertura XML to show coverage in
//// merge requests and build pages. `coverage.cobertura_path` writes this
//// XML to a file when coverage finishes. Call `render` yourself to get the
//// text without a file.
////
//// ```gleam
//// import dream_test/coverage
////
//// coverage.new()
//// |> coverage.cobertura_path("build/coverage/cobertura.xml")
//// ```
////
//// ## Shape
////
//// The XML follows the `coverage-04.dtd` shape:
////
//// - `<sources>` holds one `<source>.</source>`, the project root.
//// - Each `filename` is the source path relative to the project root, for
////   example `src/app/cart.gleam`. A CI tool joins it to the source to find
////   the file.
//// - Each directory is a `<package>`, sorted by directory. Its name is the directory with `/`
////   changed to `.`, for example `src.app`.
//// - Each source file is a `<class>`. Its name is the file name.
//// - Each executable line is a `<line>` with its `hits`.
//// - Rates have four decimal places and round down. Branch counts are `0`,
////   because coverage measures lines only.
////
//// ## Import Style
////
//// ```gleam
//// import dream_test/coverage/cobertura
//// ```

import dream_test/coverage/report.{
  type CoverageReport, type FileCoverage, type LineCoverage,
}
import gleam/int
import gleam/list
import gleam/order.{type Order}
import gleam/string

/// Render a coverage report as Cobertura XML.
///
/// ## Parameters
///
/// - `report`: the report to render
/// - `timestamp`: the `timestamp` attribute, in milliseconds since the Unix
///   epoch. `coverage.finish` gives the time it writes the file.
///
/// ## Returns
///
/// The XML document, with a newline at the end.
///
/// ## Example
///
/// ```gleam
/// report.new([
///   report.file("src/a.gleam", [
///     LineCoverage(line: 1, calls: 1),
///     LineCoverage(line: 2, calls: 0),
///   ]),
/// ])
/// |> cobertura.render(timestamp: 0)
/// // -> <?xml version="1.0" ?>
/// //    <!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-04.dtd">
/// //    <coverage line-rate="0.5000" branch-rate="0" lines-covered="1" lines-valid="2" branches-covered="0" branches-valid="0" complexity="0" version="dream_test" timestamp="0">
/// //      <sources>
/// //        <source>.</source>
/// //      </sources>
/// //      <packages>
/// //        <package name="src" line-rate="0.5000" branch-rate="0" complexity="0">
/// //          <classes>
/// //            <class name="a.gleam" filename="src/a.gleam" line-rate="0.5000" branch-rate="0" complexity="0">
/// //              <methods/>
/// //              <lines>
/// //                <line number="1" hits="1"/>
/// //                <line number="2" hits="0"/>
/// //              </lines>
/// //            </class>
/// //          </classes>
/// //        </package>
/// //      </packages>
/// //    </coverage>
/// ```
pub fn render(
  report coverage_report: CoverageReport,
  timestamp timestamp: Int,
) -> String {
  let hit = report.total_hit_line_count(coverage_report)
  let total = report.total_executable_line_count(coverage_report)
  let packages =
    coverage_report
    |> report.files()
    |> list.sort(compare_by_directory)
    |> list.chunk(directory)
    |> list.map(render_package)
  string.concat([
    "<?xml version=\"1.0\" ?>\n",
    "<!DOCTYPE coverage SYSTEM \"http://cobertura.sourceforge.net/xml/coverage-04.dtd\">\n",
    "<coverage line-rate=\"",
    line_rate(hit, total),
    "\" branch-rate=\"0\" lines-covered=\"",
    int.to_string(hit),
    "\" lines-valid=\"",
    int.to_string(total),
    "\" branches-covered=\"0\" branches-valid=\"0\" complexity=\"0\" version=\"dream_test\" timestamp=\"",
    int.to_string(timestamp),
    "\">\n",
    "  <sources>\n",
    "    <source>.</source>\n",
    "  </sources>\n",
    "  <packages>\n",
    string.concat(packages),
    "  </packages>\n",
    "</coverage>\n",
  ])
}

/// Sort by directory, then by path, so each directory is one package.
fn compare_by_directory(left: FileCoverage, right: FileCoverage) -> Order {
  string.compare(directory(left), directory(right))
  |> order.break_tie(string.compare(
    report.source_path(left),
    report.source_path(right),
  ))
}

/// The directory part of a source path, or `.` for a file at the root.
fn directory(file: FileCoverage) -> String {
  case split_path(report.source_path(file)).0 {
    [] -> "."
    directory_segments -> string.join(directory_segments, "/")
  }
}

/// The file name of a source path: the part after the last `/`.
fn file_name(path: String) -> String {
  string.concat(split_path(path).1)
}

/// The directory segments, and a list that holds only the file name.
fn split_path(path: String) -> #(List(String), List(String)) {
  let segments = string.split(path, "/")
  list.split(segments, list.length(segments) - 1)
}

/// The files of one directory, next to each other after
/// `compare_by_directory`.
fn render_package(files: List(FileCoverage)) -> String {
  let measured = report.new(files)
  let hit = report.total_hit_line_count(measured)
  let total = report.total_executable_line_count(measured)
  // Every file of a package has the same directory, so this is one name.
  let name =
    files
    |> list.map(directory)
    |> list.unique()
    |> string.concat()
    |> string.replace("/", ".")
  string.concat([
    "    <package name=\"",
    escape(name),
    "\" line-rate=\"",
    line_rate(hit, total),
    "\" branch-rate=\"0\" complexity=\"0\">\n",
    "      <classes>\n",
    string.concat(list.map(files, render_class)),
    "      </classes>\n",
    "    </package>\n",
  ])
}

fn render_class(file: FileCoverage) -> String {
  let path = report.source_path(file)
  let name = file_name(path)
  string.concat([
    "        <class name=\"",
    escape(name),
    "\" filename=\"",
    escape(path),
    "\" line-rate=\"",
    line_rate(report.hit_line_count(file), report.executable_line_count(file)),
    "\" branch-rate=\"0\" complexity=\"0\">\n",
    "          <methods/>\n",
    "          <lines>\n",
    string.concat(list.map(report.lines(file), render_line)),
    "          </lines>\n",
    "        </class>\n",
  ])
}

fn render_line(line: LineCoverage) -> String {
  "            <line number=\""
  <> int.to_string(line.line)
  <> "\" hits=\""
  <> int.to_string(line.calls)
  <> "\"/>\n"
}

/// `hit / total` with four decimal places, rounded down. No executable
/// lines gives `1.0000`, because no line was missed.
fn line_rate(hit: Int, total: Int) -> String {
  case total {
    0 -> "1.0000"
    _ -> ten_thousandths_text(hit * 10_000 / total)
  }
}

fn ten_thousandths_text(value: Int) -> String {
  int.to_string(value / 10_000)
  <> "."
  <> string.pad_start(int.to_string(value % 10_000), to: 4, with: "0")
}

/// Escape the five characters that XML gives a meaning to.
fn escape(text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
  |> string.replace("'", "&apos;")
}
