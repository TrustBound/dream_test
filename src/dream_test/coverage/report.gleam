//// Coverage data: which executable lines ran, and how often.
////
//// A `CoverageReport` is what `coverage.finish` returns. The coverage table
//// reporter renders one, and you can read one yourself to build your own
//// output (for example, CI annotations or a custom summary).
////
//// ## Reading a report
////
//// ```gleam
//// import dream_test/coverage/report
//// import gleam/int
//// import gleam/io
//// import gleam/int
////
//// pub fn print_summary(coverage_report: report.CoverageReport) -> Nil {
////   list.each(report.files(coverage_report), print_file)
//// }
////
//// fn print_file(file: report.FileCoverage) -> Nil {
////   io.println(
////     report.source_path(file)
////     <> ": "
////     <> int.to_string(report.hit_line_count(file))
////     <> "/"
////     <> int.to_string(report.executable_line_count(file)),
////   )
//// }
//// ```
////
//// ## Building a report
////
//// `report.new` and `report.file` build a report from line counts you already
//// have, so you can render it with the same table reporter.
////
//// ## Available Functions
////
//// | Category   | Functions                                                     |
//// |------------|---------------------------------------------------------------|
//// | **Build**  | `new`, `file`                                                 |
//// | **Files**  | `files`, `source_path`, `lines`                               |
//// | **Counts** | `hit_line_count`, `executable_line_count`,                    |
//// |            | `total_hit_line_count`, `total_executable_line_count`         |
////
//// ## Import Style
////
//// ```gleam
//// import dream_test/coverage/report.{type CoverageReport, LineCoverage}
//// ```

import gleam/int
import gleam/list
import gleam/order.{type Order}

/// The coverage of every measured source file.
///
/// Build one with `report.new`, or get one from `coverage.finish`.
pub opaque type CoverageReport {
  CoverageReport(files: List(FileCoverage))
}

/// The coverage of one source file.
///
/// Build one with `report.file`.
pub opaque type FileCoverage {
  FileCoverage(source_path: String, lines: List(LineCoverage))
}

/// How many times one executable line ran.
///
/// - `line`: the 1-based line number in the source file
/// - `calls`: how many times the line ran (0 means it never ran)
pub type LineCoverage {
  LineCoverage(line: Int, calls: Int)
}

/// Build a report from file coverages.
///
/// Files keep the order you give.
///
/// ## Example
///
/// ```gleam
/// report.new([
///   report.file("src/app/cart.gleam", [LineCoverage(line: 3, calls: 1)]),
/// ])
/// ```
pub fn new(files files: List(FileCoverage)) -> CoverageReport {
  CoverageReport(files: files)
}

/// Build the coverage of one source file.
///
/// Lines are sorted by line number. A line number that appears more than once
/// keeps every entry, so give each executable line once.
///
/// ## Example
///
/// ```gleam
/// report.file("src/app/cart.gleam", [
///   LineCoverage(line: 4, calls: 0),
///   LineCoverage(line: 3, calls: 2),
/// ])
/// // lines are stored as line 3, then line 4
/// ```
pub fn file(
  source_path source_path: String,
  lines lines: List(LineCoverage),
) -> FileCoverage {
  FileCoverage(source_path: source_path, lines: list.sort(lines, compare_lines))
}

fn compare_lines(left: LineCoverage, right: LineCoverage) -> Order {
  int.compare(left.line, right.line)
}

/// The files of a report, in the order they were given.
///
/// ## Example
///
/// ```gleam
/// report.new([cart_file])
/// |> report.files()
/// // -> [cart_file]
/// ```
pub fn files(report report: CoverageReport) -> List(FileCoverage) {
  report.files
}

/// The path of the source file, for example `src/app/cart.gleam`.
///
/// ## Example
///
/// ```gleam
/// report.file("src/app/cart.gleam", [])
/// |> report.source_path()
/// // -> "src/app/cart.gleam"
/// ```
pub fn source_path(file file: FileCoverage) -> String {
  file.source_path
}

/// The executable lines of the file, sorted by line number.
///
/// ## Example
///
/// ```gleam
/// report.file("src/a.gleam", [LineCoverage(line: 3, calls: 1)])
/// |> report.lines()
/// // -> [LineCoverage(line: 3, calls: 1)]
/// ```
pub fn lines(file file: FileCoverage) -> List(LineCoverage) {
  file.lines
}

/// Count the lines of a file that ran at least once.
///
/// ## Example
///
/// ```gleam
/// report.file("src/a.gleam", [
///   LineCoverage(line: 1, calls: 3),
///   LineCoverage(line: 2, calls: 0),
/// ])
/// |> report.hit_line_count()
/// // -> 1
/// ```
pub fn hit_line_count(file file: FileCoverage) -> Int {
  list.count(file.lines, line_was_hit)
}

fn line_was_hit(line: LineCoverage) -> Bool {
  line.calls > 0
}

/// Count the executable lines of a file.
///
/// Blank lines, comments and type definitions are not executable, so they
/// are not counted.
///
/// ## Example
///
/// ```gleam
/// report.file("src/a.gleam", [
///   LineCoverage(line: 1, calls: 3),
///   LineCoverage(line: 2, calls: 0),
/// ])
/// |> report.executable_line_count()
/// // -> 2
/// ```
pub fn executable_line_count(file file: FileCoverage) -> Int {
  list.length(file.lines)
}

/// Count the lines that ran, over every file in a report.
///
/// ## Example
///
/// ```gleam
/// report.new([cart_file, types_file])
/// |> report.total_hit_line_count()
/// ```
pub fn total_hit_line_count(report report: CoverageReport) -> Int {
  list.fold(report.files, 0, add_hit_lines)
}

fn add_hit_lines(total: Int, file: FileCoverage) -> Int {
  total + hit_line_count(file)
}

/// Count the executable lines, over every file in a report.
///
/// ## Example
///
/// ```gleam
/// report.new([cart_file, types_file])
/// |> report.total_executable_line_count()
/// ```
pub fn total_executable_line_count(report report: CoverageReport) -> Int {
  list.fold(report.files, 0, add_executable_lines)
}

fn add_executable_lines(total: Int, file: FileCoverage) -> Int {
  total + executable_line_count(file)
}
