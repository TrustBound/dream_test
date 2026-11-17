//// Coverage as HTML: an index and one page per source file, or one
//// combined page.
////
//// `coverage.html_path` writes the index and the source pages to a
//// directory when coverage finishes. Open `index.html` in a browser.
//// `coverage.html_file` writes the combined page to one file. Either or
//// both can be on. Call the functions here yourself to build the pages in
//// a custom pipeline, for example to serve them from a development server.
////
//// ```gleam
//// import dream_test/coverage
////
//// coverage.new()
//// |> coverage.html_path("build/coverage/html")
//// |> coverage.html_file("build/coverage/all.html")
//// ```
////
//// ## Pages
////
//// - `index.html` has a row per file like the coverage table: lines, cover,
////   missing lines and ignored lines. Excluded files have a row with their
////   pattern and reason. A `Total` row and the `Excluded:` summary follow.
////   Each file name links to its page.
//// - Each source page shows every line of the source with its line number
////   and hit count. A row has the class `hit`, `missed`, `not-executable` or
////   `ignored`. An ignored row has a `title` with its reason, and the page
////   lists the ignored ranges above the source.
//// - The combined page has the same table as `index.html`, then the same
////   annotated source of each file, in the order of the table. Each file is
////   in a `<section>` with an `id`, and each file name in the table links to
////   its section.
////
//// The pages are self-contained: the CSS is inline, there is no JavaScript
//// and nothing loads from another place. The colours follow the light or
//// dark setting of the browser. The `Cover` cell is green at `100.0%`,
//// yellow from `50.0%` and red below `50.0%`. Every path, reason and source
//// line is escaped.
////
//// ## Page paths
////
//// A source page is at `files/<source path>.html` in the directory, for
//// example `files/src/app/cart.gleam.html`. Letters, digits, `.`, `_` and
//// `-` stay as they are. Each other character becomes `~` and the two hex
//// digits of each of its UTF-8 bytes, for example a space becomes `~20`. A
//// `.` or `..` part, a folder part that ends in `.html`, and an empty part
//// (from a path that starts with `/`) are changed too, so no two source
//// paths get the same page, and no page leaves the `files` folder.
////
//// ## Section ids
////
//// The `id` of a section on the combined page is `file-` and the source
//// path, with the same character rule as page paths. A `/` also becomes
//// `~2F`. For example, `src/app/my cart.gleam` has the id
//// `file-src~2Fapp~2Fmy~20cart.gleam`. A `~` in a path becomes `~7E`, so
//// no two source paths get the same id.
////
//// ## Available Functions
////
//// | Category  | Functions                         |
//// |-----------|-----------------------------------|
//// | **Pages** | `index`, `source_page`, `combined` |
//// | **Paths** | `page_path`                       |
////
//// ## Import Style
////
//// ```gleam
//// import dream_test/coverage/html
//// ```

import dream_test/coverage/format
import dream_test/coverage/report.{
  type CoverageReport, type ExcludedFile, type FileCoverage, type IgnoredRange,
  type LineCoverage,
}
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// Render the index page of a coverage report.
///
/// ## Parameters
///
/// - `report`: the report to render
///
/// ## Returns
///
/// A complete HTML document. Each file name links to `page_path` of that
/// file, relative to the index.
///
/// ## Example
///
/// ```gleam
/// report.new([
///   report.file("src/a.gleam", [LineCoverage(line: 1, calls: 1)]),
/// ])
/// |> html.index()
/// // -> "<!DOCTYPE html>\n<html lang=\"en\">\n..."
/// ```
pub fn index(report coverage_report: CoverageReport) -> String {
  document(title: "Coverage", body: [
    "<h1>Coverage</h1>\n",
    summary_table(coverage_report, PageLinks),
  ])
}

/// Render the combined page of a coverage report: the table of the index,
/// then the annotated source of every file, on one page.
///
/// ## Parameters
///
/// - `report`: the report to render
/// - `sources`: the text of each source file, by its source path from
///   `report.source_path`. A file that is not in `sources` is shown with
///   no source text, so each line has only its number and hit count.
///
/// ## Returns
///
/// A complete HTML document. Each file name in the table links to the
/// section of that file on the same page. The module docs list how the
/// section ids are made.
///
/// ## Example
///
/// ```gleam
/// let coverage_report =
///   report.new([
///     report.file("src/a.gleam", [LineCoverage(line: 1, calls: 1)]),
///   ])
/// html.combined(
///   report: coverage_report,
///   sources: dict.from_list([#("src/a.gleam", "pub fn a() { 1 }\n")]),
/// )
/// // -> "<!DOCTYPE html>\n<html lang=\"en\">\n..."
/// ```
pub fn combined(
  report coverage_report: CoverageReport,
  sources sources: Dict(String, String),
) -> String {
  document(title: "Coverage", body: [
    "<h1>Coverage</h1>\n",
    summary_table(coverage_report, SectionLinks),
    file_sections(report.files(coverage_report), sources, []),
  ])
}

fn file_sections(
  files: List(FileCoverage),
  sources: Dict(String, String),
  sections_reversed: List(String),
) -> String {
  case files {
    [] -> string.concat(list.reverse(sections_reversed))
    [file, ..rest] ->
      file_sections(rest, sources, [
        file_section(file, sources),
        ..sections_reversed
      ])
  }
}

fn file_section(file: FileCoverage, sources: Dict(String, String)) -> String {
  let source_path = report.source_path(file)
  let source = result.unwrap(dict.get(sources, source_path), "")
  "<section id=\""
  <> section_id(source_path)
  <> "\">\n"
  <> annotated_source(file, source, "h2")
  <> "</section>\n"
}

/// The id of the section of a source file on the combined page.
fn section_id(source_path: String) -> String {
  "file-" <> encode_characters(source_path)
}

/// Where a file name in the summary table links to: its own page next to
/// the index, or its section on the combined page.
type FileLinks {
  PageLinks
  SectionLinks
}

fn file_link(links: FileLinks, source_path: String) -> String {
  case links {
    PageLinks -> page_path(source_path)
    SectionLinks -> "#" <> section_id(source_path)
  }
}

/// The table of files with a total row, and the summary of excluded files.
fn summary_table(coverage_report: CoverageReport, links: FileLinks) -> String {
  let hit = report.total_hit_line_count(coverage_report)
  let total = report.total_executable_line_count(coverage_report)
  string.concat([
    "<table>\n",
    "<thead><tr><th>File</th><th class=\"number\">Lines</th><th class=\"number\">Cover</th><th>Missing</th><th>Excluded</th></tr></thead>\n",
    "<tbody>\n",
    file_rows(report.files(coverage_report), links, []),
    string.concat(list.map(
      report.excluded_files(coverage_report),
      excluded_file_row,
    )),
    "</tbody>\n",
    "<tfoot>",
    row([
      cell("Total", ""),
      counts_cell(hit, total),
      percent_cell(hit, total),
      cell("", ""),
      cell("", ""),
    ]),
    "</tfoot>\n",
    "</table>\n",
    excluded_summary(coverage_report),
  ])
}

/// Render the page of one source file.
///
/// ## Parameters
///
/// - `file`: the coverage of the file, from `report.files`
/// - `source`: the text of the source file
///
/// ## Returns
///
/// A complete HTML document with a link back to the index, the counts of
/// the file, its ignored ranges, and a row per source line. When the
/// coverage names a line after the last line of `source`, that line is
/// shown with no text.
///
/// ## Example
///
/// ```gleam
/// report.file("src/a.gleam", [LineCoverage(line: 1, calls: 2)])
/// |> html.source_page(source: "pub fn a() { 1 }\n")
/// // -> "<!DOCTYPE html>\n<html lang=\"en\">\n..."
/// ```
pub fn source_page(file file: FileCoverage, source source: String) -> String {
  let source_path = report.source_path(file)
  document(title: source_path <> " - Coverage", body: [
    "<p><a href=\"",
    index_link(source_path),
    "\">All files</a></p>\n",
    annotated_source(file, source, "h1"),
  ])
}

/// The heading, the counts, the ignored ranges and the source rows of one
/// file. `heading` is the tag of the heading, for example `h1`.
fn annotated_source(
  file: FileCoverage,
  source: String,
  heading: String,
) -> String {
  let source_path = report.source_path(file)
  let hit = report.hit_line_count(file)
  let total = report.executable_line_count(file)
  let page =
    SourcePage(
      calls: dict.from_list(list.map(report.lines(file), line_entry)),
      ignored: list.fold(report.ignored_ranges(file), dict.new(), add_range),
    )
  let source_lines = source_lines(source)
  let line_count =
    list.fold(report.lines(file), list.length(source_lines), max_line)
  string.concat([
    "<" <> heading <> ">",
    format.escape_markup(source_path),
    "</" <> heading <> ">\n",
    "<p>Lines: ",
    format.line_counts(hit: hit, total: total),
    ". Cover: <span class=\"",
    percent_class(hit, total),
    "\">",
    format.percent(hit: hit, total: total),
    "</span>.</p>\n",
    ignored_summary(report.ignored_ranges(file)),
    "<table class=\"source\">\n",
    "<thead><tr><th class=\"number\">Line</th><th class=\"number\">Hits</th><th>Source</th></tr></thead>\n",
    "<tbody>\n",
    source_rows(page, source_lines, 1, line_count, []),
    "</tbody>\n",
    "</table>\n",
  ])
}

/// The path of the page of a source file, relative to the HTML directory.
///
/// The index links to this path, and `coverage.html_path` writes each
/// source page here. The module docs list how the path is made safe.
///
/// ## Parameters
///
/// - `source_path`: the source path, from `report.source_path`
///
/// ## Returns
///
/// The page path, for example `files/src/app/cart.gleam.html`.
///
/// ## Example
///
/// ```gleam
/// html.page_path("src/app/my cart.gleam")
/// // -> "files/src/app/my~20cart.gleam.html"
/// ```
pub fn page_path(source_path source_path: String) -> String {
  let parts = string.split(source_path, "/")
  let #(folders, file_name) = list.split(parts, list.length(parts) - 1)
  let encoded =
    list.append(
      list.map(folders, encode_folder),
      list.map(file_name, encode_part),
    )
  "files/" <> string.join(encoded, "/") <> ".html"
}

// =============================================================================
// Summary table
// =============================================================================

fn file_rows(
  files: List(FileCoverage),
  links: FileLinks,
  rows_reversed: List(String),
) -> String {
  case files {
    [] -> string.concat(list.reverse(rows_reversed))
    [file, ..rest] ->
      file_rows(rest, links, [file_row(file, links), ..rows_reversed])
  }
}

fn file_row(file: FileCoverage, links: FileLinks) -> String {
  let source_path = report.source_path(file)
  let hit = report.hit_line_count(file)
  let total = report.executable_line_count(file)
  row([
    "<td><a href=\""
      <> format.escape_markup(file_link(links, source_path))
      <> "\">"
      <> format.escape_markup(source_path)
      <> "</a></td>",
    counts_cell(hit, total),
    percent_cell(hit, total),
    cell(string.join(format.missed_lines(file), ", "), ""),
    cell(
      string.join(
        list.map(report.ignored_ranges(file), format.ignored_range),
        ", ",
      ),
      "",
    ),
  ])
}

fn excluded_file_row(file: ExcludedFile) -> String {
  row([
    cell(report.excluded_source_path(file), ""),
    cell("", ""),
    cell("", ""),
    cell("", ""),
    cell(format.excluded_file(file), ""),
  ])
}

fn counts_cell(hit: Int, total: Int) -> String {
  cell(format.line_counts(hit: hit, total: total), "number")
}

fn percent_cell(hit: Int, total: Int) -> String {
  cell(
    format.percent(hit: hit, total: total),
    "number " <> percent_class(hit, total),
  )
}

/// Green at 100%, yellow from 50%, red below 50%. A file with no executable
/// lines counts as fully covered.
fn percent_class(hit: Int, total: Int) -> String {
  case hit == total, hit * 2 >= total {
    True, _ -> "complete"
    False, True -> "partial"
    False, False -> "low"
  }
}

fn excluded_summary(coverage_report: CoverageReport) -> String {
  case format.excluded_summary(coverage_report) {
    Some(summary) -> "<p>" <> format.escape_markup(summary) <> "</p>\n"
    None -> ""
  }
}

fn row(cells: List(String)) -> String {
  "<tr>" <> string.concat(cells) <> "</tr>\n"
}

fn cell(text: String, class: String) -> String {
  "<td"
  <> class_attribute(class)
  <> ">"
  <> format.escape_markup(text)
  <> "</td>"
}

fn class_attribute(class: String) -> String {
  case class {
    "" -> ""
    _ -> " class=\"" <> class <> "\""
  }
}

// =============================================================================
// Source pages
// =============================================================================

/// What a source page knows about each line: the hit count of each
/// executable line, and the reason of each ignored line.
type SourcePage {
  SourcePage(calls: Dict(Int, Int), ignored: Dict(Int, Option(String)))
}

fn line_entry(line: LineCoverage) -> #(Int, Int) {
  #(line.line, line.calls)
}

fn add_range(
  ignored: Dict(Int, Option(String)),
  range: IgnoredRange,
) -> Dict(Int, Option(String)) {
  add_range_lines(
    ignored,
    report.ignored_first_line(range),
    report.ignored_last_line(range),
    report.ignored_reason(range),
  )
}

fn add_range_lines(
  ignored: Dict(Int, Option(String)),
  line_number: Int,
  last_line: Int,
  reason: Option(String),
) -> Dict(Int, Option(String)) {
  case line_number > last_line {
    True -> ignored
    False ->
      add_range_lines(
        dict.insert(ignored, line_number, reason),
        line_number + 1,
        last_line,
        reason,
      )
  }
}

/// The lines of the source. A newline at the end does not start a line.
fn source_lines(source: String) -> List(String) {
  let lines = string.split(source, "\n")
  case string.ends_with(source, "\n") {
    True -> list.take(lines, list.length(lines) - 1)
    False -> lines
  }
}

fn max_line(line_count: Int, line: LineCoverage) -> Int {
  int.max(line_count, line.line)
}

fn index_link(source_path: String) -> String {
  let depth = list.length(string.split(page_path(source_path), "/")) - 1
  string.repeat("../", depth) <> "index.html"
}

fn ignored_summary(ranges: List(IgnoredRange)) -> String {
  case ranges {
    [] -> ""
    _ ->
      "<p>Ignored: "
      <> format.escape_markup(string.join(
        list.map(ranges, format.ignored_range),
        ", ",
      ))
      <> "</p>\n"
  }
}

fn source_rows(
  page: SourcePage,
  lines: List(String),
  line_number: Int,
  line_count: Int,
  rows_reversed: List(String),
) -> String {
  case line_number > line_count, lines {
    True, _ -> string.concat(list.reverse(rows_reversed))
    False, [text, ..rest] ->
      source_rows(page, rest, line_number + 1, line_count, [
        source_row(page, line_number, text),
        ..rows_reversed
      ])
    False, [] ->
      source_rows(page, [], line_number + 1, line_count, [
        source_row(page, line_number, ""),
        ..rows_reversed
      ])
  }
}

fn source_row(page: SourcePage, line_number: Int, text: String) -> String {
  let #(attributes, count) = line_state(page, line_number)
  "<tr"
  <> attributes
  <> "><td class=\"number\">"
  <> int.to_string(line_number)
  <> "</td><td class=\"number\">"
  <> count
  <> "</td><td>"
  <> format.escape_markup(text)
  <> "</td></tr>\n"
}

/// The row attributes and the hit count text of one line.
fn line_state(page: SourcePage, line_number: Int) -> #(String, String) {
  case dict.get(page.calls, line_number), dict.get(page.ignored, line_number) {
    Ok(0), _ -> #(" class=\"missed\"", "0")
    Ok(calls), _ -> #(" class=\"hit\"", int.to_string(calls))
    Error(Nil), Ok(reason) -> #(
      " class=\"ignored\" title=\"" <> ignored_title(reason) <> "\"",
      "ignored",
    )
    Error(Nil), Error(Nil) -> #(" class=\"not-executable\"", "")
  }
}

fn ignored_title(reason: Option(String)) -> String {
  case reason {
    Some(text) -> "ignored: " <> format.escape_markup(text)
    None -> "ignored"
  }
}

// =============================================================================
// Shared
// =============================================================================

fn document(title title: String, body body: List(String)) -> String {
  string.concat([
    "<!DOCTYPE html>\n",
    "<html lang=\"en\">\n",
    "<head>\n",
    "<meta charset=\"utf-8\">\n",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n",
    "<title>",
    format.escape_markup(title),
    "</title>\n",
    "<style>\n",
    string.join(style_rules, "\n"),
    "\n</style>\n",
    "</head>\n",
    "<body>\n",
    string.concat(body),
    "</body>\n",
    "</html>\n",
  ])
}

const style_rules = [
  ":root { color-scheme: light dark; --text: #1f2328; --background: #ffffff; --border: #d0d7de; --muted: #59636e; --hit: #dafbe1; --missed: #ffebe9; --ignored: #eaeef2; --complete: #1a7f37; --partial: #9a6700; --low: #cf222e; }",
  "@media (prefers-color-scheme: dark) { :root { --text: #e6edf3; --background: #0d1117; --border: #30363d; --muted: #9198a1; --hit: #12261e; --missed: #301418; --ignored: #1c2128; --complete: #3fb950; --partial: #d29922; --low: #f85149; } }",
  "body { margin: 16px; font-family: system-ui, sans-serif; color: var(--text); background: var(--background); }",
  "a { color: inherit; }",
  "table { border-collapse: collapse; }",
  "th, td { padding: 2px 8px; border-bottom: 1px solid var(--border); text-align: left; vertical-align: top; }",
  ".number { text-align: right; }",
  ".complete { color: var(--complete); }",
  ".partial { color: var(--partial); }",
  ".low { color: var(--low); }",
  ".source td { border-bottom: 0; font-family: ui-monospace, monospace; white-space: pre; }",
  ".source td.number { color: var(--muted); }",
  "tr.hit { background: var(--hit); }",
  "tr.missed { background: var(--missed); }",
  "tr.ignored { background: var(--ignored); }",
]

// =============================================================================
// Page paths
// =============================================================================

/// A folder part that ends in `.html` gets its last `.` escaped, so it never
/// has the name of a page.
fn encode_folder(part: String) -> String {
  case string.ends_with(part, ".html") {
    True -> encode_characters(string.drop_end(part, 5)) <> "~2Ehtml"
    False -> encode_part(part)
  }
}

fn encode_part(part: String) -> String {
  case part {
    "" -> "~"
    "." -> "~2E"
    ".." -> "~2E~2E"
    _ -> encode_characters(part)
  }
}

fn encode_characters(text: String) -> String {
  string.concat(list.map(string.to_utf_codepoints(text), encode_codepoint))
}

fn encode_codepoint(codepoint: UtfCodepoint) -> String {
  case is_safe_character(string.utf_codepoint_to_int(codepoint)) {
    True -> string.from_utf_codepoints([codepoint])
    False -> encode_bytes(<<codepoint:utf8_codepoint>>, "")
  }
}

/// Letters, digits, `.`, `_` and `-`.
fn is_safe_character(code: Int) -> Bool {
  case code {
    _ if code >= 97 && code <= 122 -> True
    _ if code >= 65 && code <= 90 -> True
    _ if code >= 48 && code <= 57 -> True
    46 | 95 | 45 -> True
    _ -> False
  }
}

fn encode_bytes(bytes: BitArray, encoded: String) -> String {
  case bytes {
    <<byte, rest:bytes>> ->
      encode_bytes(
        rest,
        encoded
          <> "~"
          <> string.pad_start(int.to_base16(byte), to: 2, with: "0"),
      )
    _ -> encoded
  }
}
